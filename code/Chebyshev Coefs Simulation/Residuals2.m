function f=Residuals2(coef,r,T,dT,loc0,loc1,lambda,alpha,beta,power_b,fixed_costs,coalition_fixed_costs_sum)
% RESIDUALS2 evaluates terminal-state HJB collocation residuals.
% This state has no further tipping transition or continuation-value term.

n=length(alpha);
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

% Evaluate each value function and its temperature derivative.
fval = zeros(n-m+1,Nnode);
dfval = zeros(n-m+1,Nnode);
for ii = 1:n-m+1
    for i = 1:Nnode
        fval(ii,i) = sum(coefmatrix(ii,:).*T(i,:));
        dfval(ii,i) = sum(coefmatrix(ii,:).*dT(i,:));
    end
end

q = zeros(n,Nnode);
for i = 1:Nnode
    for j=1:length(loc0)
        q(loc0(j),i) = ((alpha(loc0(j))+lambda*dfval(j+1, i))/beta(loc0(j)))^(1/(power_b-1));
        if (alpha(loc0(j))+lambda*dfval(j+1, i))/beta(loc0(j)) < 0
            disp((alpha(loc0(j))+lambda*dfval(j+1, i))/beta(loc0(j)))
            break
        end
    end
    for j=1:length(loc1)
        q(loc1(j),i) = ((alpha(loc1(j))+lambda*dfval(1, i))/beta(loc1(j)))^(1/(power_b-1));
        if (alpha(loc1(j))+lambda*dfval(1, i))/beta(loc1(j)) < 0
            disp((alpha(loc1(j))+lambda*dfval(1, i))/beta(loc1(j)))
            break
        end
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
% Coalition residual at every Chebyshev node.
f(1:Nnode) = -r * fval(1,:) + ...
           coalition_benefits_sum - ... 
           coalition_fixed_costs_sum + ...    
           lambda * dfval(1,:) .* sum_q;

% Outsider residuals at every Chebyshev node.
for j = 1:length(loc0)
    for i = 1:Nnode
        f(Nnode * j + i) = -r * fval(j + 1, i) + ...
                           benefits(loc0(j),i) - ...         
                           fixed_costs(loc0(j),i) + ...       
                           lambda * sum_q(i) * dfval(j + 1, i);        
    end
end

end
