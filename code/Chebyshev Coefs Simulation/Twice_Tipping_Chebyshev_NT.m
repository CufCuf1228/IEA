function [coefs_NT_2tipped, coefs_NT_1tipped_lowTemp, coefs_NT_1tipped_highTemp, coefs_NT_0tipped_lowTemp, coefs_NT_0tipped_highTemp] = ...
    Twice_Tipping_Chebyshev_NT(power_b, Tat0, Tat2, Tat, alpha1, beta1, gamma, eta, chi1, chi2, lambda, r, maxdegree, tip, con, lossrate, rm, ...
    coefs_2tipped, coefs_1tipped_lowTemp, coefs_1tipped_highTemp, coefs_0tipped_lowTemp, coefs_0tipped_highTemp)
% TWICE_TIPPING_CHEBYSHEV_NT decomposes coalition values by member region.
% It returns no-transfer individual Chebyshev coefficients for all two-tipping states.

    n = length(alpha1);
    L1 = tip(1);
    L2 = tip(2);

    country = 1:n;
    start = 0;

    for i = 1:n
        num = nchoosek(n, i);
        final = start + num;
        state = nchoosek(country, i);
        statete = zeros(num, n);

        for j = 1:num
            for k = 1:n
                if any(state(j,:) == k)
                    statete(j,k) = 1;
                else
                    statete(j,k) = 0;
                end
            end
        end

        allstate(start+1:final, 1) = i;
        allstate(start+1:final, 2:n+1) = statete;
        start = final;
    end

    nn = size(allstate, 1);
    degree = maxdegree;
    len_block = degree + 1;

    % Validate the input coefficient layouts.
    min_col = n * len_block;

    if size(coefs_2tipped, 2) < min_col
        error('coefs_2tipped does not have enough columns for maxdegree.');
    end
    if size(coefs_1tipped_lowTemp, 2) < min_col
        error('coefs_1tipped_lowTemp does not have enough columns for maxdegree.');
    end
    if size(coefs_1tipped_highTemp, 2) < min_col
        error('coefs_1tipped_highTemp does not have enough columns for maxdegree.');
    end
    if size(coefs_0tipped_lowTemp, 2) < min_col
        error('coefs_0tipped_lowTemp does not have enough columns for maxdegree.');
    end
    if size(coefs_0tipped_highTemp, 2) < min_col
        error('coefs_0tipped_highTemp does not have enough columns for maxdegree.');
    end

    % Each output row is a coalition with one Chebyshev block per region.
    coefs_NT_2tipped          = zeros(nn, n * len_block);
    coefs_NT_1tipped_lowTemp  = zeros(nn, n * len_block);
    coefs_NT_1tipped_highTemp = zeros(nn, n * len_block);
    coefs_NT_0tipped_lowTemp  = zeros(nn, n * len_block);
    coefs_NT_0tipped_highTemp = zeros(nn, n * len_block);

    % Precompute basis matrices for the full, low, and high intervals.
    [T_full, dT_full, z_full, ~] = CalculateChebyshevMatrices(degree, Tat0, Tat);
    [T_low,  dT_low,  z_low,  ~] = CalculateChebyshevMatrices(degree, Tat0, Tat2);
    [T_high, dT_high, z_high, ~] = CalculateChebyshevMatrices(degree, Tat2, Tat);

    Nnode_full = size(T_full, 1);
    Nnode_low  = size(T_low, 1);
    Nnode_high = size(T_high, 1);

    % Precompute baseline regional damage costs on each interval.
    base_cost_full = zeros(n, Nnode_full);
    base_cost_low  = zeros(n, Nnode_low);
    base_cost_high = zeros(n, Nnode_high);

    for j = 1:n
        base_cost_full(j,:) = 0.5 * gamma(j) * (z_full').^2 + eta(j) * z_full';
        base_cost_low(j,:)  = 0.5 * gamma(j) * (z_low').^2  + eta(j) * z_low';
        base_cost_high(j,:) = 0.5 * gamma(j) * (z_high').^2 + eta(j) * z_high';
    end

    hWait = waitbar(0, 'Computing two-tipping NT individual value functions...');

    % Recover no-transfer individual value functions coalition by coalition.
    for i = 1:nn

        m = allstate(i, 1);
        counsta = allstate(i, 2:n+1);
        loc1 = find(counsta == 1);
        loc0 = find(counsta == 0);
        is_member = false(1, n);
        is_member(loc1) = true;
        loc0_pos = zeros(1, n);
        loc0_pos(loc0) = 1:length(loc0);
        alpha = alpha1;
        beta  = beta1;

        if m > 1
            for j = 1:n
                if counsta(j) == 1
                    alpha(j) = alpha1(j) * (1 + rm(i) .* con);
                    beta(j)  = beta1(j)  * (1 + rm(i) .* con);
                else
                    alpha(j) = alpha1(j) * (1 - rm(i) .* lossrate);
                    beta(j)  = beta1(j)  * (1 - rm(i) .* lossrate);
                end
            end
        end

        % State 2: both tipping events have occurred.
        tipDam = (1 + L1) * (1 + L2);
        T = T_full;
        dT = dT_full;
        z = z_full;
        fixed_costs = tipDam * base_cost_full;
        coefs_orig = coefs_2tipped(i, 1:(n-m+1)*len_block);
        [~, sum_q, benefits] = Calculate_Q_and_Benefits( ...
            coefs_orig, T, dT, loc0, loc1, lambda, alpha, beta, power_b);

        M = r .* T - lambda .* bsxfun(@times, sum_q(:), dT);
        for j = 1:n
            idx = (j-1)*len_block+1 : j*len_block;
            if is_member(j)
                Y = benefits(j,:)' - fixed_costs(j,:)';
                coefs_NT_2tipped(i, idx) = (M \ Y)';
            else
                k = loc0_pos(j);
                if k == 0
                    error('Invalid outsider index at coalition row %d, country %d.', i, j);
                end
                src_idx = k*len_block+1 : (k+1)*len_block;
                coefs_NT_2tipped(i, idx) = coefs_orig(src_idx);
            end
        end

        % State 1 on the low-temperature interval.
        tipDam = 1 + L1;
        T = T_low;
        dT = dT_low;
        z = z_low;
        fixed_costs = tipDam * base_cost_low;
        coefs_orig = coefs_1tipped_lowTemp(i, 1:(n-m+1)*len_block);
        [~, sum_q, benefits] = Calculate_Q_and_Benefits( ...
            coefs_orig, T, dT, loc0, loc1, lambda, alpha, beta, power_b);
        M = r .* T - lambda .* bsxfun(@times, sum_q(:), dT);
        for j = 1:n
            idx = (j-1)*len_block+1 : j*len_block;
            if is_member(j)
                Y = benefits(j,:)' - fixed_costs(j,:)';
                coefs_NT_1tipped_lowTemp(i, idx) = (M \ Y)';
            else
                k = loc0_pos(j);
                if k == 0
                    error('Invalid outsider index at coalition row %d, country %d.', i, j);
                end
                src_idx = k*len_block+1 : (k+1)*len_block;
                coefs_NT_1tipped_lowTemp(i, idx) = coefs_orig(src_idx);
            end
        end

        % State 1 on the high-temperature interval with second-event risk.
        tipDam = 1 + L1;
        T = T_high;
        dT = dT_high;
        z = z_high;
        fixed_costs = tipDam * base_cost_high;
        h2 = chi2 * (z' - Tat2);
        coefs_orig = coefs_1tipped_highTemp(i, 1:(n-m+1)*len_block);
        [~, sum_q, benefits] = Calculate_Q_and_Benefits( ...
            coefs_orig, T, dT, loc0, loc1, lambda, alpha, beta, power_b);
        M = bsxfun(@times, r + h2(:), T) - lambda .* bsxfun(@times, sum_q(:), dT);
        for j = 1:n
            idx = (j-1)*len_block+1 : j*len_block;
            if is_member(j)
                fval2_j = ChebyEval(z', coefs_NT_2tipped(i, idx), Tat0, Tat);
                Y = benefits(j,:)' - fixed_costs(j,:)' + h2(:) .* fval2_j(:);
                coefs_NT_1tipped_highTemp(i, idx) = (M \ Y)';
            else
                k = loc0_pos(j);
                if k == 0
                    error('Invalid outsider index at coalition row %d, country %d.', i, j);
                end
                src_idx = k*len_block+1 : (k+1)*len_block;
                coefs_NT_1tipped_highTemp(i, idx) = coefs_orig(src_idx);
            end
        end

        % State 0 on the low-temperature interval.
        tipDam = 1;
        T = T_low;
        dT = dT_low;
        z = z_low;
        fixed_costs = tipDam * base_cost_low;
        h1 = chi1 * (z' - Tat0);
        coefs_orig = coefs_0tipped_lowTemp(i, 1:(n-m+1)*len_block);
        [~, sum_q, benefits] = Calculate_Q_and_Benefits( ...
            coefs_orig, T, dT, loc0, loc1, lambda, alpha, beta, power_b);
        M = bsxfun(@times, r + h1(:), T) - lambda .* bsxfun(@times, sum_q(:), dT);
        for j = 1:n
            idx = (j-1)*len_block+1 : j*len_block;
            if is_member(j)
                fval2_j = ChebyEval(z', coefs_NT_1tipped_lowTemp(i, idx), Tat0, Tat2);
                Y = benefits(j,:)' - fixed_costs(j,:)' + h1(:) .* fval2_j(:);
                coefs_NT_0tipped_lowTemp(i, idx) = (M \ Y)';
            else
                k = loc0_pos(j);
                if k == 0
                    error('Invalid outsider index at coalition row %d, country %d.', i, j);
                end
                src_idx = k*len_block+1 : (k+1)*len_block;
                coefs_NT_0tipped_lowTemp(i, idx) = coefs_orig(src_idx);
            end
        end

        % State 0 on the high-temperature interval with first-event risk.
        tipDam = 1;
        T = T_high;
        dT = dT_high;
        z = z_high;
        fixed_costs = tipDam * base_cost_high;
        h1 = chi1 * (z' - Tat0);
        coefs_orig = coefs_0tipped_highTemp(i, 1:(n-m+1)*len_block);
        [~, sum_q, benefits] = Calculate_Q_and_Benefits( ...
            coefs_orig, T, dT, loc0, loc1, lambda, alpha, beta, power_b);
        M = bsxfun(@times, r + h1(:), T) - lambda .* bsxfun(@times, sum_q(:), dT);
        for j = 1:n
            idx = (j-1)*len_block+1 : j*len_block;
            if is_member(j)
                fval2_j = ChebyEval(z', coefs_NT_1tipped_highTemp(i, idx), Tat2, Tat);
                Y = benefits(j,:)' - fixed_costs(j,:)' + h1(:) .* fval2_j(:);
                coefs_NT_0tipped_highTemp(i, idx) = (M \ Y)';
            else
                k = loc0_pos(j);
                if k == 0
                    error('Invalid outsider index at coalition row %d, country %d.', i, j);
                end
                src_idx = k*len_block+1 : (k+1)*len_block;
                coefs_NT_0tipped_highTemp(i, idx) = coefs_orig(src_idx);
            end
        end

        if mod(i, 50) == 0 || i == nn
            waitbar(i/nn, hWait, ...
                sprintf('Computing NT coefficients: %d / %d (%.1f%%)', i, nn, i/nn*100));
        end
    end

    close(hWait);

end
