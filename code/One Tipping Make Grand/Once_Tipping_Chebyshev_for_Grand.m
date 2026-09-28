function [coa_state, coefs_1tipped, coefs_0tipped_lowTemp, coefs_0tipped_highTemp] = ...
    Once_Tipping_Chebyshev_for_Grand(power_b, Tat_start, Tat_mid, Tat_end, alpha, beta, gamma, eta, chi1, lambda, r, maxdegree, tip, con, lossrate, rm)

Tat_end   = Tat_end;
Tat_start = Tat_start;
Tat_mid   = Tat_mid;

power_b = power_b;

alpha_init = alpha;
beta_init  = beta;

gamma = gamma;
eta   = eta;

n = length(alpha);

chi1   = chi1;
lambda = lambda;
r      = r;

L = tip;  % one tipping damage multiplier parameter


% Enumerate every nonempty coalition.
country = 1:n;
start = 0;
for i = 1:n
    num = nchoosek(n,i);
    final = start + num;
    state = nchoosek(country,i);
    statete = zeros(num,n);

    for j = 1:num
        for k = 1:n
           loc = find(state(j,:) == k);
           if isempty(loc)
               statete(j,k) = 0;
           else
               statete(j,k) = 1;
           end
        end
    end

    allstate(start+1:final,1) = i;            % coalition size
    allstate(start+1:final,2:n+1) = statete;  % coalition membership vector

    start = final;
    clear statete state final loc
end


% Keep n single-region exits plus the grand coalition.
% For n = 12, these are rows 4083:4095 in the full 4095-state matrix.
nn_full = size(allstate,1);
nn = n + 1;

allstate = allstate(nn_full-n:nn_full,:);
coa_state = allstate;


% rm may contain all 4095 coalitions or only the final n+1 target states.
if size(rm,1) > nn
    rm_local = rm(end-n:end,:);
else
    rm_local = rm;
end


%%%%%%% fsolve options %%%%%%%
options = optimoptions('fsolve', ...
    'Algorithm', 'trust-region-dogleg', ...
    'Display', 'final', ...
    'FunctionTolerance', 1.0000e-06, ...
    'OptimalityTolerance', 1.0000e-09, ...
    'StepTolerance', 1.0000e-06, ...
    'MaxFunctionEvaluations', 1.0e+06, ...
    'MaxIterations', 1.0e+06);

options1 = optimoptions('fsolve', ...
    'Algorithm', 'trust-region', ...
    'Display', 'final', ...
    'FunctionTolerance', 1.0000e-06, ...
    'OptimalityTolerance', 1.0000e-09, ...
    'StepTolerance', 1.0000e-06, ...
    'MaxFunctionEvaluations', 1.0e+06, ...
    'MaxIterations', 1.0e+06);


%%%%%%% coefficient containers %%%%%%%
maxdegree = maxdegree;

coefs_1tipped          = zeros(nn,n*(maxdegree+1));
coefs_0tipped_lowTemp  = zeros(nn,n*(maxdegree+1));
coefs_0tipped_highTemp = zeros(nn,n*(maxdegree+1));


% For power_b = 2, use the analytical solution to validate or replace the numerical solution.
if power_b == 2
    tipDam = 1 + L;
    paraat1 = AnalyticalSol(alpha_init, beta_init, gamma, eta, ...
                                lambda, r, tipDam, con, lossrate, rm_local);
end


% Solve Chebyshev coefficients for every target coalition state.
for i = 1:nn

    m = allstate(i,1);
    counsta = allstate(i,2:n+1);

    loc1 = find(counsta == 1);
    loc0 = find(counsta == 0);

    % Adjust alpha and beta for connection or sanctions.
    alpha = alpha_init;
    beta  = beta_init;

    if m > 1
        for j = 1:n
            if allstate(i,j+1) == 1
                alpha(j) = alpha_init(j) * (1 + rm_local(i) .* con);
                beta(j)  = beta_init(j)  * (1 + rm_local(i) .* con);
            end

            if allstate(i,j+1) == 0
                alpha(j) = alpha_init(j) * (1 - rm_local(i) .* lossrate);
                beta(j)  = beta_init(j)  * (1 - rm_local(i) .* lossrate);
            end
        end
    end


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 1. Post-tipping state: coefs_1tipped.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    tipDam = 1 + L;
    gamma1 = gamma .* tipDam;
    eta1   = eta   .* tipDam;

    degree = 2;

    [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = ...
        InitialCoefs(degree,Tat_start,Tat_end,n,alpha,beta,lambda,power_b,gamma1,eta1,r,loc0,loc1);

    [coefs1,fval,exitflag,output] = ...
        fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum), ...
        coef0,options);

    if exitflag ~= 1
        [coefs1,fval,exitflag,output] = ...
            fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum), ...
            coefs1,options1);
    end

    while degree < maxdegree
        degreeLow = degree;

        if degree == maxdegree - 1
            degree = degreeLow + 1;
        else
            degree = degreeLow + 2;
        end

        [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = ...
            UpdateInitCoefs(degreeLow,degree,coefs1,n,m,Tat_start,Tat_end,gamma1,eta1,loc1);

        [coefs1,fval,exitflag,output] = ...
            fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum), ...
            coef0,options);
    end

    if exitflag ~= 1
        [coefs1,fval,exitflag,output] = ...
            fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum), ...
            coefs1,options1);
    end

    if exitflag ~= 1
        disp(sprintf('One tipped with degree %d',degree))
        exitflag
        i
        allstate(i,:)
        break;
    end


    % For power_b = 2, construct analytical Chebyshev coefficients and compare them with the numerical solution.
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

        for j = 1:length(loc0)
            for j2 = 1:degree+1
                coef0(j*(degree+1)+j2) = 2*(fvals(loc0(j),:)*T(:,j2))/Nnode;
            end
            coef0(j*(degree+1)+1) = coef0(j*(degree+1)+1)/2;
        end

        coefs1_anal = coef0;

        res_anal = Residuals2(coefs1_anal,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum);

        if max(abs(res_anal)) > 0.0001
            disp(sprintf('Either analytical solution or Residuals2 is wrong'))
            i
            allstate(i,:)
            res_anal'
            break;
        end

        diffCoef = abs(coefs1_anal - coefs1)./(1+abs(coefs1_anal));

        if max(diffCoef) > 0.0001
            disp(sprintf('Mismatch between analytical and numerical solution'))
            i
            allstate(i,:)
            res_numer = Residuals2(coefs1,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum)
            break;
        end

        coefs1 = coefs1_anal;
    end


    % Store the post-tipping value-function coefficients.
    coefmatrix_1tipped = zeros(n-m+1,degree+1);

    for ii = 1:n-m+1
        for j = 1:degree+1
            coefmatrix_1tipped(ii,j) = coefs1((ii-1)*(degree+1)+j);
        end
    end

    for ii = 1:length(coefs1)
        coefs_1tipped(i,ii) = coefs1(ii);
    end


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 2. Pre-tipping low-temperature state: coefs_0tipped_lowTemp.
    %    T in [Tat_start, Tat_mid]
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    gamma0 = gamma;
    eta0   = eta;

    degree = 2;

    [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = ...
        InitialCoefs(degree,Tat_start,Tat_mid,n,alpha,beta,lambda,power_b,gamma0,eta0,r,loc0,loc1);

    [coefs2,fval,exitflag,output] = ...
        fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum), ...
        coef0,options);

    if exitflag ~= 1
        [coefs2,fval,exitflag,output] = ...
            fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum), ...
            coefs2,options1);
    end

    while degree < maxdegree
        degreeLow = degree;

        if degree == maxdegree - 1
            degree = degreeLow + 1;
        else
            degree = degreeLow + 2;
        end

        [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = ...
            UpdateInitCoefs(degreeLow,degree,coefs2,n,m,Tat_start,Tat_mid,gamma0,eta0,loc1);

        [coefs2,fval,exitflag,output] = ...
            fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum), ...
            coef0,options);
    end

    if exitflag ~= 1
        [coefs2,fval,exitflag,output] = ...
            fsolve(@(coef) Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum), ...
            coefs2,options1);
    end

    if exitflag <= 0
        disp(sprintf('No tipped with low temp and degree %d',degree))
        exitflag
        i
        allstate(i,:)
        break;
    end


    % Store the pre-tipping low-temperature coefficients.
    coefmatrix_0tipped_lowTemp = zeros(n-m+1,degree+1);

    for ii = 1:n-m+1
        for j = 1:degree+1
            coefmatrix_0tipped_lowTemp(ii,j) = coefs2((ii-1)*(degree+1)+j);
        end
    end

    for ii = 1:length(coefs2)
        coefs_0tipped_lowTemp(i,ii) = coefs2(ii);
    end


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 3. Pre-tipping high-temperature state: coefs_0tipped_highTemp.
    %    T in [Tat_mid, Tat_end]
    %    Include the hazard term and post-tipping continuation value.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    degree = 2;

    [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = ...
        InitialCoefs(degree,Tat_mid,Tat_end,n,alpha,beta,lambda,power_b,gamma0,eta0,r,loc0,loc1);

    h1 = chi1*(z' - Tat_mid);

    Nnode = degree + 1;
    fval2 = zeros(n-m+1, Nnode);

    for ii = 1:n-m+1
        fval2(ii, 1:Nnode) = ChebyEval(z, coefmatrix_1tipped(ii,:), Tat_start,Tat_end);
    end

    [coefs2,fval,exitflag,output] = ...
        fsolve(@(coef) Residuals1(coef, r, h1, T, dT, loc0, loc1, lambda, alpha, beta, power_b, fixed_costs, coalition_fixed_costs_sum, fval2), ...
        coef0,options);

    if exitflag ~= 1
        [coefs2,fval,exitflag,output] = ...
            fsolve(@(coef) Residuals1(coef, r, h1, T, dT, loc0, loc1, lambda, alpha, beta, power_b, fixed_costs, coalition_fixed_costs_sum, fval2), ...
            coefs2,options1);
    end

    while degree < maxdegree
        degreeLow = degree;

        if degree == maxdegree - 1
            degree = degreeLow + 1;
        else
            degree = degreeLow + 2;
        end

        [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = ...
            UpdateInitCoefs(degreeLow,degree,coefs2,n,m,Tat_mid,Tat_end,gamma0,eta0,loc1);

        h1 = chi1*(z' - Tat_mid);

        Nnode = degree + 1;
        fval2 = zeros(n-m+1, Nnode);

        for ii = 1:n-m+1
            fval2(ii, 1:Nnode) = ChebyEval(z, coefmatrix_1tipped(ii,:), Tat_start,Tat_end);
        end

        [coefs2,fval,exitflag,output] = ...
            fsolve(@(coef) Residuals1(coef, r, h1, T, dT, loc0, loc1, lambda, alpha, beta, power_b, fixed_costs, coalition_fixed_costs_sum, fval2), ...
            coef0,options);
    end

    if exitflag ~= 1
        [coefs2,fval,exitflag,output] = ...
            fsolve(@(coef) Residuals1(coef, r, h1, T, dT, loc0, loc1, lambda, alpha, beta, power_b, fixed_costs, coalition_fixed_costs_sum, fval2), ...
            coefs2,options1);
    end

    if exitflag <= 0
        disp(sprintf('No tipped with high temp and degree %d',degree))
        exitflag
        i
        allstate(i,:)
        break;
    end


    % Store the pre-tipping high-temperature coefficients.
    coefmatrix_0tipped_highTemp = zeros(n-m+1,degree+1);

    for ii = 1:n-m+1
        for j = 1:degree+1
            coefmatrix_0tipped_highTemp(ii,j) = coefs2((ii-1)*(degree+1)+j);
        end
    end

    for ii = 1:length(coefs2)
        coefs_0tipped_highTemp(i,ii) = coefs2(ii);
    end

end

end
