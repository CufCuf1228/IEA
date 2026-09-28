function [coef0,T,dT,fixed_costs,coalition_fixed_costs_sum,z] = UpdateInitCoefs(degreeLow,degree,coefLow,n,m,Tat0,Tat,gamma,eta,loc1)

    Nnode = degree+1;

    [T, dT, z, dz] = CalculateChebyshevMatrices(degree, Tat0, Tat);
    
    fixed_costs = zeros(n,Nnode);
    for j=1:n
        fixed_costs(j,:) = 0.5*gamma(j) * (z').^2 + eta(j) * z';
    end

    coalition_fixed_costs_sum = zeros(1,Nnode);
    for j=1:length(loc1)
        coalition_fixed_costs_sum = coalition_fixed_costs_sum + fixed_costs(loc1(j),:);
    end

    coef0 = zeros(1,(n-m+1)*(degree+1)); 
    for ii=1:n-m+1
        for j=1:degreeLow+1
            coef0((ii-1)*(degree+1)+j) = coefLow((ii-1)*(degreeLow+1)+j);
        end
    end

end