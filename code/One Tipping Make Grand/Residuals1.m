function f = Residuals1(coef, r, h2, T, dT, loc0, loc1, lambda, alpha, beta, power_b, fixed_costs, coalition_fixed_costs_sum, fval2)

n=12;
m=length(loc1);
Nnode = size(T,1);
degree1 = size(T,2);
coefmatrix=ones(n-m+1,degree1);

% Reshape the stacked coefficient vector by value-function block.
for i = 1:n-m+1
    for j = 1:degree1
        coefmatrix(i,j)=coef((i-1)*(degree1)+j);
    end
end


fval = zeros(n-m+1, Nnode);
dfval = zeros(n-m+1, Nnode);
for ii = 1:n-m+1
    for i = 1:Nnode
        fval(ii, i) = sum(coefmatrix(ii, :) .* T(i, :));
        dfval(ii, i) = sum(coefmatrix(ii, :) .* dT(i, :));
    end
end


q = zeros(n,Nnode);
for i = 1:Nnode
    for j=1:length(loc0)
        q(loc0(j),i) = ((alpha(loc0(j))+lambda*dfval(j+1, i))/beta(loc0(j)))^(1/(power_b-1));
    end
    for j=1:length(loc1)
        q(loc1(j),i) = ((alpha(loc1(j))+lambda*dfval(1, i))/beta(loc1(j)))^(1/(power_b-1));
    end
end

sum_q = sum(q,1);

benefits = zeros(n,Nnode);
for j=1:n
    benefits(j,:) = alpha(j)*q(j,:) - beta(j)/power_b*q(j,:).^power_b;
end

coalition_benefits_sum = zeros(1,Nnode);
for j=1:length(loc1)
    coalition_benefits_sum = coalition_benefits_sum + benefits(loc1(j),:);
end

f = zeros(Nnode*(length(loc0)+1),1);   
f(1:Nnode) = -(r + h2) .* fval(1,:) + ... % -[r+h2]*V^2
           coalition_benefits_sum - ... 
           coalition_fixed_costs_sum + ...    
           lambda * dfval(1,:) .* sum_q + ... % lambda*dV^2/dT*U
           h2 .* fval2(1,:);             % h2*V^1

for j = 1:length(loc0) % Loop over outsiders.
    for i = 1:Nnode % Loop over Chebyshev nodes.
        f(Nnode * j + i) = -(r + h2(i)) * fval(j + 1, i) + ...
                           benefits(loc0(j),i) - ...         
                           fixed_costs(loc0(j),i) + ...       
                           lambda * sum_q(i) * dfval(j + 1, i) + ... 
                           h2(i)*fval2(j+1,i);        
    end
end

end
