function [q, sum_q, benefits] = Calculate_Q_and_Benefits(coef_original, T, dT, loc0, loc1, lambda, alpha, beta, power_b)
% CALCULATE_Q_AND_BENEFITS recovers regional emissions and flow benefits.
% Coefficients are ordered as one coalition block followed by outsider blocks.

    n = length(alpha);
    m = length(loc1);
    Nnode = size(T,1);
    degree1 = size(T,2);
    
    % Reshape the stacked Chebyshev coefficients by value-function block.
    coefmatrix = zeros(n-m+1, degree1);
    for ii = 1:n-m+1
        coefmatrix(ii,:) = coef_original((ii-1)*degree1+1 : ii*degree1);
    end

    % Evaluate the temperature derivative of each value function at all nodes.
    dfval = zeros(n-m+1, Nnode);
    for ii = 1:n-m+1
        for i_n = 1:Nnode
            dfval(ii,i_n) = sum(coefmatrix(ii,:) .* dT(i_n,:));
        end
    end

    % Apply the emission first-order condition to members and outsiders.
    q = zeros(n, Nnode);
    for i_n = 1:Nnode
        for j=1:length(loc0)
            q(loc0(j),i_n) = ((alpha(loc0(j))+lambda*dfval(j+1, i_n))/beta(loc0(j)))^(1/(power_b-1));
        end
        for j=1:length(loc1)
            q(loc1(j),i_n) = ((alpha(loc1(j))+lambda*dfval(1, i_n))/beta(loc1(j)))^(1/(power_b-1));
        end
    end
    
    sum_q = sum(q, 1);
    
    % Compute regional flow benefits at the implied emissions.
    benefits = zeros(n, Nnode);
    for j = 1:n
        benefits(j,:) = alpha(j)*q(j,:) - (beta(j)/power_b)*q(j,:).^power_b;
    end
end
