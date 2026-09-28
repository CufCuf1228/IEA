function [all_final_profit] = PerformShapleyAllocation(all_profit, first_one_indices, allstate, location)

[nn, cols] = size(allstate);
n = cols - 1; 
all_final_profit = zeros(nn, n);

% Singleton or noncooperative states.
all_final_profit(1:12, :) = all_profit(1:12, :);

for i = n+1:nn
    
    current_state = allstate(i, 2:end);
    insiders = find(current_state == 1); 
    outsiders = find(current_state == 0);
    
    m = length(insiders);

    for k = 1:length(outsiders)
        out_id = outsiders(k);
        all_final_profit(i, out_id) = all_profit(i, out_id);
    end
    
    % --- Compute Shapley allocations for coalition members. ---
    shapley_values = zeros(1, n);
    num_subsets = 2^m - 1;
    
    for mask = 1:num_subsets

        subset_mask = bitget(mask, 1:m) == 1;
        subset_indices = insiders(subset_mask);
        s_size = length(subset_indices);
        
        to_remove_indices = insiders(~subset_mask);
        
        row_idx_Ss = i; 
        for r = 1:length(to_remove_indices)
            rem_id = to_remove_indices(r);
            row_idx_Ss = location(row_idx_Ss, rem_id);
        end
        
        % Obtain V(Ss).
        leader_Ss = first_one_indices(row_idx_Ss);
        v_Ss = all_profit(row_idx_Ss, leader_Ss);
        
        % 3. Compute the Shapley weight.
        weight = (factorial(s_size - 1) * factorial(m - s_size)) / factorial(m);
        
        % 4. Compute the marginal contribution V(Ss) - V(Ss \ {p}).
        for k = 1:s_size
            member_p = subset_indices(k);
            
            if s_size == 1
                v_prev = 0;
            else
                row_idx_prev = location(row_idx_Ss, member_p);
                
                leader_prev = first_one_indices(row_idx_prev);
                v_prev = all_profit(row_idx_prev, leader_prev);
            end
            
            % Accumulate the weighted contribution.
            marginal_contribution = v_Ss - v_prev;
            shapley_values(member_p) = shapley_values(member_p) + weight * marginal_contribution;
        end
    end
    
    % Store the allocated values.
    for k = 1:m
        member_id = insiders(k);
        all_final_profit(i, member_id) = shapley_values(member_id);
    end
end

end
