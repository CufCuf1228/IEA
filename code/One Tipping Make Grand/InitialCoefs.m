function [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = InitialCoefs(degree,Tat0,Tat,n,alpha,beta,lambda,power_b,gamma,eta,r,loc0,loc1)

    Nnode=degree+1;

    linCoef = -1;

    [T, dT, z, dz] = CalculateChebyshevMatrices(degree, Tat0, Tat);

    qinit = zeros(n,1);
    for j=1:length(loc0)
        qinit(loc0(j)) = ((alpha(loc0(j))+lambda*linCoef*dz)/beta(loc0(j)))^(1/(power_b-1));
    end
    for j=1:length(loc1)
        qinit(loc1(j)) = ((alpha(loc1(j))+lambda*linCoef*dz)/beta(loc1(j)))^(1/(power_b-1));
    end

    benefitInit = zeros(n,1);
    fixed_costs = zeros(n,Nnode);
    
    for j=1:n
        benefitInit(j) = alpha(j)*qinit(j) - beta(j)/power_b*qinit(j)^power_b;
        fixed_costs(j,:) = 0.5*gamma(j) * (z').^2 + eta(j) * z';
    end

    coalition_benefits_sum = 0;
    coalition_fixed_costs_sum = zeros(1,Nnode);
    for j=1:length(loc1)
        coalition_benefits_sum = coalition_benefits_sum + benefitInit(loc1(j));
        coalition_fixed_costs_sum = coalition_fixed_costs_sum + fixed_costs(loc1(j),:);
    end
    
    sum_q = sum(qinit);

    coef0(1) = (coalition_benefits_sum - coalition_fixed_costs_sum((Nnode+1)/2) + lambda * linCoef*dz * sum_q) / r;
    coef0(2) = linCoef;
    coef0(3) = 0;    
    
    for j=1:length(loc0)
        coef0(j*(degree+1)+1) = (benefitInit(loc0(j)) - fixed_costs(loc0(j)) + lambda * linCoef*dz * sum_q) / r;   
        coef0(j*(degree+1)+2) = linCoef;
        coef0(j*(degree+1)+3) = 0;        
    end    

end
