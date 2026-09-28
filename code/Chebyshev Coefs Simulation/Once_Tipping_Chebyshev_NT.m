function [coefs_NT_1tipped, coefs_NT_0tipped_lowTemp, coefs_NT_0tipped_highTemp] = ...
    Once_Tipping_Chebyshev_NT(power_b, Tat_start, Tat_mid, Tat_end, alpha1, beta1, gamma, eta, chi1, lambda, r, maxdegree, tip, con, lossrate, rm, ...
    coefs_1tipped, coefs_0tipped_lowTemp, coefs_0tipped_highTemp)
% ONCE_TIPPING_CHEBYSHEV_NT decomposes coalition values by member region.
% It returns no-transfer individual Chebyshev coefficients for all one-tipping states.

    n = length(alpha1);
    L = tip;

    % Enumerate every nonempty coalition.
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

    if size(coefs_1tipped, 2) < min_col
        error('coefs_1tipped does not have enough columns for maxdegree.');
    end
    if size(coefs_0tipped_lowTemp, 2) < min_col
        error('coefs_0tipped_lowTemp does not have enough columns for maxdegree.');
    end
    if size(coefs_0tipped_highTemp, 2) < min_col
        error('coefs_0tipped_highTemp does not have enough columns for maxdegree.');
    end

    % Each output row is a coalition with one Chebyshev block per region.
    coefs_NT_1tipped          = zeros(nn, n * len_block);
    coefs_NT_0tipped_lowTemp  = zeros(nn, n * len_block);
    coefs_NT_0tipped_highTemp = zeros(nn, n * len_block);

    % Precompute basis matrices for the full, low, and high intervals.
    [T_full, dT_full, z_full, ~] = CalculateChebyshevMatrices(degree, Tat_start, Tat_end);
    [T_low,  dT_low,  z_low,  ~] = CalculateChebyshevMatrices(degree, Tat_start, Tat_mid);
    [T_high, dT_high, z_high, ~] = CalculateChebyshevMatrices(degree, Tat_mid, Tat_end);

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

    hWait = waitbar(0, 'Computing one-tipping NT individual value functions...');

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

        % State 1: tipping has occurred.
        tipDam = 1 + L;
        T = T_full;
        dT = dT_full;
        z = z_full;
        fixed_costs = tipDam * base_cost_full;
        coefs_orig = coefs_1tipped(i, 1:(n-m+1)*len_block);
        [~, sum_q, benefits] = Calculate_Q_and_Benefits( ...
            coefs_orig, T, dT, loc0, loc1, lambda, alpha, beta, power_b);

        M = r .* T - lambda .* bsxfun(@times, sum_q(:), dT);
        for j = 1:n
            idx = (j-1)*len_block+1 : j*len_block;
            if is_member(j)
                Y = benefits(j,:)' - fixed_costs(j,:)';
                coefs_NT_1tipped(i, idx) = (M \ Y)';

            else
                k = loc0_pos(j);
                if k == 0
                    error('Invalid outsider index at coalition row %d, country %d.', i, j);
                end
                src_idx = k*len_block+1 : (k+1)*len_block;
                coefs_NT_1tipped(i, idx) = coefs_orig(src_idx);
            end
        end

        % State 0, low-temperature interval: tipping has not occurred.
        tipDam = 1;
        T = T_low;
        dT = dT_low;
        z = z_low;
        fixed_costs = tipDam * base_cost_low;
        coefs_orig = coefs_0tipped_lowTemp(i, 1:(n-m+1)*len_block);
        [~, sum_q, benefits] = Calculate_Q_and_Benefits( ...
            coefs_orig, T, dT, loc0, loc1, lambda, alpha, beta, power_b);

        M = r .* T - lambda .* bsxfun(@times, sum_q(:), dT);
        for j = 1:n
            idx = (j-1)*len_block+1 : j*len_block;
            if is_member(j)
                Y = benefits(j,:)' - fixed_costs(j,:)';
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

        % State 0, high-temperature interval: tipping remains possible.
        tipDam = 1;
        T = T_high;
        dT = dT_high;
        z = z_high;
        fixed_costs = tipDam * base_cost_high;
        % Tipping risk becomes active above Tat_mid.
        h1 = chi1 * (z' - Tat_mid);
        coefs_orig = coefs_0tipped_highTemp(i, 1:(n-m+1)*len_block);
        [~, sum_q, benefits] = Calculate_Q_and_Benefits( ...
            coefs_orig, T, dT, loc0, loc1, lambda, alpha, beta, power_b);

        M = bsxfun(@times, r + h1(:), T) ...
            - lambda .* bsxfun(@times, sum_q(:), dT);
        for j = 1:n
            idx = (j-1)*len_block+1 : j*len_block;
            if is_member(j)
                % Evaluate the post-jump state on the full temperature interval.
                fval2_j = ChebyEval(z', coefs_NT_1tipped(i, idx), Tat_start, Tat_end);
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
