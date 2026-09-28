function [all_profit] = GetNationFutureProfit_NoTransfer(nn, n, maxdegree, alstate, current_temp, current_coefs, low_Tat, high_Tat)
% Compute future profits under the updated no-transfer coefficient format.
% current_coefs stores one independent value-function block per region in order 1:n.
% Evaluate each Chebyshev polynomial directly at current_temp; no forward simulation is required.

all_profit = zeros(nn, n); 
len_block = maxdegree + 1; % Number of coefficients in each block.

for i = 1:nn
    % Process all regions.
    for j = 1:n
        % Extract the block using the absolute region index j.
        idx_start = (j - 1) * len_block + 1;
        idx_end   = j * len_block;
        c_poly_j = current_coefs(i, idx_start:idx_end);
        
        % Evaluate the individual value function at the current temperature.
        all_profit(i, j) = ChebyEval(current_temp, c_poly_j, low_Tat, high_Tat);
    end
end

end
