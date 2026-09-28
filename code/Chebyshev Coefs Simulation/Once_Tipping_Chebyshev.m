function [Flag] = Once_Tipping_Chebyshev(power_b, Tat_start, Tat_mid, Tat_end, alpha, beta, gamma, eta, chi1, lambda, r, maxdegree, tip, con, lossrate, rm, damage_power)
% ONCE_TIPPING_CHEBYSHEV solves the core one-tipping model.
% damage_power is 2 for quadratic damage and 4 for quartic damage.

Tat_end=Tat_end;
Tat_start=Tat_start;
Tat_mid=Tat_mid;

power_b=power_b; % Exponent in the benefit function.

alpha_init=alpha;
beta_init=beta;

gamma=gamma;
eta=eta;

% Number of regions.
n=length(alpha);

chi1=chi1;
lambda=lambda;

r=r;

L=tip; % Proportional tipping damage increment.

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
coefs_1tipped = zeros(nn,n*(maxdegree+1));
coefs_0tipped_lowTemp = zeros(nn,n*(maxdegree+1));
coefs_0tipped_highTemp = zeros(nn,n*(maxdegree+1));


% Filename suffix: tip_tec_lossrate_power_b_maxdegree_r.
mystr = strcat(num2str(tip),'_',num2str(con),'_',num2str(lossrate),'_',num2str(power_b),'_',num2str(maxdegree),'_',num2str(r));
use_analytical_solution = power_b == 2 && damage_power == 2;
if use_analytical_solution
    tipDam = 1+L;
    paraat1 = AnalyticalSol(alpha, beta, gamma, eta, lambda, r, tipDam, con, lossrate, rm);
end

if damage_power == 4
    saveDir = fullfile('.', 'One Tipping Chebyshev Coefs', ...
        'One Tipping ChebyEval Results SA Dam_Fun Power_b_4');
elseif power_b == 2
    saveDir = fullfile('.', 'One Tipping Chebyshev Coefs test', ...
        'One Tipping ChebyEval Results SA Benchmark');
else
    saveDir = fullfile('.', 'One Tipping Chebyshev Coefs test', ...
        strcat('One Tipping ChebyEval Results SA Benchmark',num2str(power_b)));
end
mkdir(saveDir);


% Track progress over coalition structures.
hWait = waitbar(0, 'Initializing computation...');

% Solve all tipping states for each coalition.
for i=1:nn
    m=allstate(i,1);
    counsta=allstate(i,2:n+1);  
    loc1=find(counsta==1);
    loc0=find(counsta==0);

    alpha = alpha_init;
    beta = beta_init;
    if m>1
        for j=1:n
            if allstate(i,j+1)==1
                alpha(j)=alpha_init(j)*(1+rm(i).*con);
                beta(j)=beta_init(j)*(1+rm(i).*con);
            end
            if allstate(i,j+1)==0
                alpha(j)=alpha_init(j)*(1-rm(i).*lossrate);
                beta(j)=beta_init(j)*(1-rm(i).*lossrate);
            end
        end
    end    

    % Post-tipping state on the full temperature interval.
    tipDam = 1+L;
    gamma1 = gamma.*tipDam;
    eta1 = eta.*tipDam;

    degree = 2;
    [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = InitialCoefs(degree,Tat_start,Tat_end,n,alpha,beta,lambda,power_b,gamma1,eta1,r,loc0,loc1,damage_power);
    
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

        [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = UpdateInitCoefs(degreeLow,degree,coefs1,n,m,Tat_start,Tat_end,gamma1,eta1,loc1,damage_power);
        [coefs1,fval,exitflag,output]  = fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum),coef0,options);
    end

    if exitflag ~= 1
        [coefs1,fval,exitflag,output]  = fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum),coefs1,options1);
    end            
    
    if exitflag ~= 1
        disp(sprintf('One tipped with degree %d',degree))
        exitflag
        i
        allstate(i,:)        
        break;
    end

    if use_analytical_solution
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

    % Reshape and store the post-tipping coefficient blocks.
    coefmatrix_1tipped = zeros(n-m+1,degree+1);
    for ii = 1:n-m+1
        for j = 1:degree+1
            coefmatrix_1tipped(ii,j)=coefs1((ii-1)*(degree+1)+j);
        end
    end

    for ii = 1:length(coefs1)
        coefs_1tipped(i,ii) = coefs1(ii);
    end

    % Pre-tipping state.
    gamma0 = gamma;
    eta0 = eta;

    % Low-temperature interval below Tat_mid, where tipping risk is inactive.

    degree = 2;
    [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = InitialCoefs(degree,Tat_start,Tat_mid,n,alpha,beta,lambda,power_b,gamma0,eta0,r,loc0,loc1,damage_power);

    [coefs2,fval,exitflag,output]  = fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum),coef0,options);
    if exitflag ~= 1
        [coefs2,fval,exitflag,output]  = fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum),coefs2,options1);
    end

    while degree < maxdegree
        degreeLow = degree;
        if degree == maxdegree - 1
            degree = degreeLow + 1;
        else
            degree = degreeLow + 2;
        end
        [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = UpdateInitCoefs(degreeLow,degree,coefs2,n,m,Tat_start,Tat_mid,gamma0,eta0,loc1,damage_power);

        [coefs2,fval,exitflag,output]  = fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum),coef0,options);
    end

    if exitflag ~= 1
        [coefs2,fval,exitflag,output]  = fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum),coefs2,options1);
    end
    
    if exitflag <= 0
        disp(sprintf('No tipped with low temp and degree %d',degree))
        exitflag
        i
        allstate(i,:)        
        break;
    end

    % Reshape and store the low-temperature coefficient blocks.
    coefmatrix_0tipped_lowTemp = zeros(n-m+1,degree+1);
    for ii = 1:n-m+1
        for j = 1:degree+1
            coefmatrix_0tipped_lowTemp(ii,j)=coefs2((ii-1)*(degree+1)+j);
        end
    end    

    for ii = 1:length(coefs2)
        coefs_0tipped_lowTemp(i,ii) = coefs2(ii);
    end


    % High-temperature interval above Tat_mid, including tipping risk.

    degree = 2;
    [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = InitialCoefs(degree,Tat_mid,Tat_end,n,alpha,beta,lambda,power_b,gamma0,eta0,r,loc0,loc1,damage_power);

    h1=chi1*(z'-Tat_mid);

    Nnode = degree+1;
    fval2 = zeros(n-m+1, Nnode); 
    for ii = 1:n-m+1    
        fval2(ii, 1:Nnode) = ChebyEval(z, coefmatrix_1tipped(ii,:), Tat_start,Tat_end);
    end

    [coefs2,fval,exitflag,output] = fsolve(@(coef) Residuals1(coef, r, h1, T, dT, loc0, loc1, lambda, alpha, beta, power_b, fixed_costs, coalition_fixed_costs_sum, fval2),coef0,options);
    if exitflag ~= 1
        [coefs2,fval,exitflag,output] = fsolve(@(coef) Residuals1(coef, r, h1, T, dT, loc0, loc1, lambda, alpha, beta, power_b, fixed_costs, coalition_fixed_costs_sum, fval2),coefs2,options1);
    end

    while degree < maxdegree
        degreeLow = degree;
        if degree == maxdegree - 1
            degree = degreeLow + 1;
        else
            degree = degreeLow + 2;
        end
        [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = UpdateInitCoefs(degreeLow,degree,coefs2,n,m,Tat_mid,Tat_end,gamma0,eta0,loc1,damage_power);

        h1=chi1*(z'-Tat_mid);

        Nnode = degree+1;
        fval2 = zeros(n-m+1, Nnode); 
        for ii = 1:n-m+1
            fval2(ii, 1:Nnode) = ChebyEval(z, coefmatrix_1tipped(ii,:), Tat_start,Tat_end);
        end

        [coefs2,fval,exitflag,output] = fsolve(@(coef) Residuals1(coef, r, h1, T, dT, loc0, loc1, lambda, alpha, beta, power_b, fixed_costs, coalition_fixed_costs_sum, fval2),coef0,options);
    end

    if exitflag ~= 1
        [coefs2,fval,exitflag,output] = fsolve(@(coef) Residuals1(coef, r, h1, T, dT, loc0, loc1, lambda, alpha, beta, power_b, fixed_costs, coalition_fixed_costs_sum, fval2),coefs2,options1);
    end    

    if exitflag <= 0
        disp(sprintf('One tipped with high temp and degree %d',degree))
        exitflag
        i
        allstate(i,:)        
        break;
    end

    % Reshape and store the high-temperature coefficient blocks.
    coefmatrix_0tipped_highTemp = zeros(n-m+1,degree+1);
    for ii = 1:n-m+1
        for j = 1:degree+1
            coefmatrix_0tipped_highTemp(ii,j)=coefs2((ii-1)*(degree+1)+j);
        end
    end

    for ii = 1:length(coefs2)
        coefs_0tipped_highTemp(i,ii) = coefs2(ii);
    end


    % Update coalition progress.
    waitbar(i/nn, hWait, sprintf('Computing coalitions: %d / %d (%.1f%%)', i, nn, i/nn*100));
end

% Close the progress display and save all state-specific coefficient matrices.
close(hWait);
save(fullfile(saveDir, strcat('coefs1_onetipping_',mystr,'.mat')),'coefs_1tipped') % Post-tipping coefficients.
save(fullfile(saveDir, strcat('coefs1_notipping_lowT_',mystr,'.mat')),'coefs_0tipped_lowTemp') % Pre-tipping, low-temperature coefficients.
save(fullfile(saveDir, strcat('coefs1_notipping_highT_',mystr,'.mat')),'coefs_0tipped_highTemp') % Pre-tipping, high-temperature coefficients.

Flag = "Complete!";


end
