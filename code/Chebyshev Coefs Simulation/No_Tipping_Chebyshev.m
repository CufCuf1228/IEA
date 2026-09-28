function [Flag] = No_Tipping_Chebyshev(power_b, Tat_start, Tat_end, alpha, beta, gamma, eta, chi1, lambda, r, maxdegree, con, lossrate, rm)
% NO_TIPPING_CHEBYSHEV solves the no-tipping robustness specification.
% It computes coalition and outsider value functions by Chebyshev collocation.
Tat_end=Tat_end;
Tat_start=Tat_start;

power_b=power_b; % Exponent in the benefit function.

alpha1=alpha;
beta1=beta;

gamma=gamma;
eta=eta;


% Number of regions.
n=length(alpha);

chi1=chi1;
lambda=lambda;

r=r;

L=0; % No tipping damage multiplier.

% Enumerate every nonempty coalition.
country=1:n;
start=0;
for i=1:n
    num=nchoosek(n,i);
    final=start+num;
    state=nchoosek(country,i);
    statete = zeros(num,n);
    for j=1:num
        for k=1:n
           loc=find(state(j,:)==k);
           if isempty(loc)
               statete(j,k)=0;
           else
               statete(j,k)=1;
           end
        end
    end
    allstate(start+1:final,1)=i;             % Coalition size.
    allstate(start+1:final,2:n+1)=statete;   % Coalition membership indicators.
    start=final;
    clear statete state final loc
end

nn=size(allstate,1);

options = optimoptions('fsolve', ...
    'Algorithm', 'trust-region-dogleg', ...
    'Display', 'final', ...
    'FunctionTolerance', 1.0000e-06, ...
    'OptimalityTolerance', 1.0000e-09, ...
    'StepTolerance', 1.0000e-06, ...
    'MaxFunctionEvaluations', 1.0e+06,...
    'MaxIterations', 1.0e+06);

options1 = optimoptions('fsolve', ...
    'Algorithm', 'trust-region', ...
    'Display', 'final', ...
    'FunctionTolerance', 1.0000e-06, ...
    'OptimalityTolerance', 1.0000e-09, ...
    'StepTolerance', 1.0000e-06, ...
    'MaxFunctionEvaluations', 1.0e+06,...
    'MaxIterations', 1.0e+06);

maxdegree = maxdegree;
coefs_0tipped = zeros(nn,n*(maxdegree+1));


% Filename suffix: 0_tec_lossrate_power_b_maxdegree.
mystr = strcat('0_',num2str(con),'_',num2str(lossrate),'_',num2str(power_b),'_',num2str(maxdegree));
if power_b == 2
    tipDam = 1+L;
    paraat1 = AnalyticalSol(alpha, beta, gamma, eta, lambda, r, tipDam, con, lossrate, rm);
    saveDir = fullfile('.', 'No Tipping ChebyEval Results Power_b_2');
else
    saveDir = fullfile('.', strcat('No Tipping ChebyEval Results Power_b_',num2str(power_b)));
end
mkdir(saveDir);


% Track progress over coalition structures.
hWait = waitbar(0, 'Initializing computation...');

% Solve one value-function system for each coalition.
for i=1:nn
    m=allstate(i,1);
    counsta=allstate(i,2:n+1);  
    loc1=find(counsta==1);
    loc0=find(counsta==0);

    alpha = alpha1;
    beta = beta1;
    if m>1
        for j=1:n
            if allstate(i,j+1)==1
                alpha(j)=alpha1(j)*(1+rm(i).*con);
                beta(j)=beta1(j)*(1+rm(i).*con);
            end
            if allstate(i,j+1)==0
                alpha(j)=alpha1(j)*(1-rm(i).*lossrate);
                beta(j)=beta1(j)*(1-rm(i).*lossrate);
            end
        end
    end    

    % Solve the no-tipping state, increasing the polynomial degree gradually.
    degree = 2;
    [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = InitialCoefs(degree,Tat_start,Tat_end,n,alpha,beta,lambda,power_b,gamma,eta,r,loc0,loc1,2);
    
    [coefs1,fval,exitflag,output]  = fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum),coef0,options);  
    if exitflag ~= 1
        [coefs1,fval,exitflag,output]  = fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum),coefs1,options1);
    end            

    while degree < maxdegree
        degreeLow = degree;
        if degree == maxdegree - 1
            degree = degreeLow + 1;
        else
            degree = degreeLow + 2;
        end

        [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = UpdateInitCoefs(degreeLow,degree,coefs1,n,m,Tat_start,Tat_end,gamma,eta,loc1,2);
        [coefs1,fval,exitflag,output]  = fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum),coef0,options);
    end

    if exitflag ~= 1
        [coefs1,fval,exitflag,output]  = fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum),coefs1,options1);
    end            
    
    if exitflag ~= 1
        disp(sprintf('No tipped with degree %d',degree))
        exitflag
        i
        allstate(i,:)        
        break;
    end

    if power_b == 2
        Nnode = degree + 1;
        fvals = zeros(n,Nnode);
        for j = 1:n
             fvals(j,:) = paraat1(i,j) + paraat1(i,j+n)*z + 0.5.*paraat1(i,j+2*n)*z.^2;
        end
    
        fval_coalition = fvals(loc1(1),:);
        for j = 1:degree+1
            coef0(j) = 2*(fval_coalition*T(:,j))/Nnode;
        end
        coef0(1) = coef0(1)/2;
    
        for j=1:length(loc0)
            for j2 = 1:degree+1
                coef0(j*(degree+1)+j2) = 2*(fvals(loc0(j),:)*T(:,j2))/Nnode;
            end
            coef0(j*(degree+1)+1) = coef0(j*(degree+1)+1)/2;
        end
        coefs1_anal = coef0;
        res_anal=Residuals2(coefs1_anal,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum);
        if max(abs(res_anal)) > 0.0001
            disp(sprintf('Either analytical solution or Residuals2 is wrong'))            
            i
            allstate(i,:)   
            res_anal'
            break;
        end

        diffCoef = abs(coefs1_anal - coefs1)./(1+abs(coefs1_anal));
        if max(diffCoef)>0.0001
            disp(sprintf('Mismatch between analytical and numerical solution'))
            i
            allstate(i,:)     
            res_numer = Residuals2(coefs1,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum)
            break;
        end
        coefs1 = coefs1_anal;
    end

    % Reshape and store the converged coefficient blocks.
    coefmatrix_0tipped = zeros(n-m+1,degree+1);
    for ii = 1:n-m+1
        for j = 1:degree+1
            coefmatrix_0tipped(ii,j)=coefs1((ii-1)*(degree+1)+j);
        end
    end

    for ii = 1:length(coefs1)
        coefs_0tipped(i,ii) = coefs1(ii);
    end


    % Update coalition progress.
    waitbar(i/nn, hWait, sprintf('Computing coalitions: %d / %d (%.1f%%)', i, nn, i/nn*100));
end

% Close the progress display and save the coefficient matrix.
close(hWait);
save(fullfile(saveDir, strcat('coefs0_notipping_',mystr,'.mat')),'coefs_0tipped') % Numerical coefficients.

Flag = "Complete!";


end
