function [all_profit] = GetNationFutureProfit(nn, n, power_b, maxdegree, allstate, alstate, current_temp, current_coefs, low_Tat, high_Tat)


all_profit = zeros(nn, n); % Initialize the coalition-by-region profit matrix.
len_block = maxdegree + 1; % Number of coefficients in each block.

for i = 1:nn
    % 1. Read the coalition membership state for this row.
    current_state = alstate(i, :);       % Binary membership vector.
    insiders = find(current_state == 1); % Member indices.
    outsiders = find(current_state == 0);% Ordered outsider indices.

    % 2. Evaluate the aggregate coalition value.
    % The first coefficient block stores the total coalition value.
    if ~isempty(insiders)
        % Extract the first coefficient block.
        idx_start = 1;
        idx_end = len_block;
        c_poly_coa = current_coefs(i, idx_start:idx_end);
        
        % Store the aggregate coalition value at the first member's index.
        coa_id = insiders(1); 
        all_profit(i, coa_id) = ChebyEval(current_temp, c_poly_coa, low_Tat, high_Tat);
    end
    

    % 3. Evaluate each outsider's value function.
    % Subsequent coefficient blocks correspond to outsiders in order.
    for k = 1:length(outsiders)
        country_id = outsiders(k);
        
        % Block 1 is the coalition, so outsider k uses block k+1.
        block_idx = k + 1; 
        idx_start = (block_idx-1)*len_block + 1;
        idx_end   = block_idx*len_block;
        
        c_poly_out = current_coefs(i, idx_start:idx_end);
        
        % Store the value in the corresponding region column.
        all_profit(i, country_id) = ChebyEval(current_temp, c_poly_out, low_Tat, high_Tat);
    end
end
end
