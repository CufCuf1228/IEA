function [TraceTemp, TraceState, TraceUtility, TraceCoaNum, TraceCoa, TraceEmission, TraceBenifit] = Twice_Tipping_Allocation(allocation_type, start_year, end_year, tip_year1, tip_year2, Tat0, Tat2, Tat, ...
                                                                        coefs_2tipped, coefs_1tipped_lowTemp, coefs_1tipped_highTemp, coefs_0tipped_lowTemp, coefs_0tipped_highTemp,...
                                                                        power_b, maxdegree, alpha, beta, gamma, eta, r, tip, allstate, alstate, starttemp, lambda, first_one_indices, con, lossrate, rm)
% TWICE_TIPPING_ALLOCATION finds stable coalitions after two tipping events.
% It returns annual temperature, coalition, utility, emission, and benefit paths.
n = length(alpha);
nn = 2^n - 1;

L1=tip(1);  % First tipping damage increment.
L2=tip(2);

TraceTemp = starttemp;
TraceState = [];
TraceUtility = [];
TraceCoaNum =[];
TraceCoa = {};
TraceEmission = [];
current_year = start_year;
TraceBenifit = [];


% 1. Build the state-transition matrix.
location = zeros(nn, n);
for i = 1:nn
    for j = 1:n
        if allstate(i, j+1) == 1
            sta = allstate(i, :);
            sta(1) = allstate(i, 1) - 1;   
            sta(j+1) = allstate(i, j+1) - 1; 
            
            if sta(1) == 0
                location(i, j) = i; 
            else
                idx = find(ismember(allstate, sta, 'rows') == 1);
                location(i, j) = idx;
            end
        else
            sta = allstate(i, :);
            sta(1) = allstate(i, 1) + 1;   
            sta(j+1) = allstate(i, j+1) + 1; 
            
            idx = find(ismember(allstate, sta, 'rows') == 1);
            location(i, j) = idx;
        end
    end
end

while current_year <= end_year                            
    current_temp = TraceTemp(end);
    if current_year < tip_year1
        if current_temp < Tat2
            current_coefs = coefs_0tipped_lowTemp;
            low_Tat = Tat0;
            high_Tat = Tat2;
        elseif (Tat2 <= current_temp) && (current_temp < Tat)
            current_coefs = coefs_0tipped_highTemp;
            low_Tat = Tat2;
            high_Tat = Tat;
        end
        new_gamma = gamma;
        new_eta = eta;
    elseif (tip_year1 <= current_year) && (current_year < tip_year2)
        if current_temp < Tat2
            current_coefs = coefs_1tipped_lowTemp;
            low_Tat = Tat0;
            high_Tat = Tat2;
        elseif current_temp < Tat
            current_coefs = coefs_1tipped_highTemp;
            low_Tat = Tat2;
            high_Tat = Tat;
        end
        new_gamma = (1+L1)*gamma;
        new_eta = (1+L1)*eta;
    else
        current_coefs = coefs_2tipped;
        low_Tat = Tat0;
        high_Tat = Tat;
        new_gamma = (1+L1)*(1+L2)*gamma;
        new_eta = (1+L1)*(1+L2)*eta;
    end

    % 1. Evaluate future regional profits for every coalition.
    if allocation_type == "NoTransfer"
        all_final_profit = GetNationFutureProfit_NoTransfer(nn, n, maxdegree, alstate, current_temp, current_coefs, low_Tat, high_Tat);
    else
        all_profit = GetNationFutureProfit(nn, n, power_b, maxdegree, allstate, alstate, current_temp, current_coefs, low_Tat, high_Tat);
        all_final_profit = PerformShapleyAllocation(all_profit, first_one_indices, allstate, location);
    end

    
    % 2. Check internal and external stability.
    all_final_profit_new = zeros(nn, n);
    for i = 1:nn
       for j = 1:n
           all_final_profit_new(i, j) = all_final_profit(location(i, j), j);
       end
    end

    deltasta = all_final_profit_new - all_final_profit;
    check = (deltasta > 0); 
    numcheck = sum(check, 2);
    isstable = find(numcheck == 0);
    isstable = isstable(isstable > n);
    
    if isempty(isstable)
        isstable = [1];
        numisstable = 0;
    else
        numisstable = length(isstable);
    end

    % 3. Select the best stable coalition and update the trajectories.
    stablestate = alstate(isstable, :); 
    [~, max_idx_local] = max(sum(all_final_profit(isstable, :) .* stablestate, 2)); 
    maxindex = isstable(max_idx_local);


    % Compute temperature change and emissions.
    current_state = alstate(maxindex, :);       
    insiders = find(current_state == 1);
    outsiders = find(current_state == 0);
   
    m = length(insiders);
    new_alpha = alpha;
    new_beta = beta;

    if m>1
        for j=1:n
            if allstate(maxindex,j+1)==1
                new_alpha(j)=alpha(j)*(1+rm(maxindex).*con);
                new_beta(j)=beta(j)*(1+rm(maxindex).*con);
            end
            if allstate(maxindex,j+1)==0
                new_alpha(j)=alpha(j)*(1-rm(maxindex).*lossrate);
                new_beta(j)=beta(j)*(1-rm(maxindex).*lossrate);
            end
        end
    end

    len_block = maxdegree + 1;
    
    if allocation_type == "NoTransfer"
        % NT format: sum the region-ordered individual blocks to obtain coalition value.
        c_poly_coa = zeros(1, len_block);
        for k = 1:length(insiders)
            cid = insiders(k);
            c_poly_coa = c_poly_coa + current_coefs(maxindex, (cid-1)*len_block+1 : cid*len_block);
        end
        VsT = ChebyshevDeriv(current_temp, c_poly_coa, low_Tat, high_Tat);
        
        WsT = zeros(1,n);
        for k = 1:length(outsiders)
            cid = outsiders(k);
            c_poly_out = current_coefs(maxindex, (cid-1)*len_block+1 : cid*len_block);
            WsT(cid) = ChebyshevDeriv(current_temp, c_poly_out, low_Tat, high_Tat);
        end
    else
        % Standard format: block 1 is coalition value; block k+1 is outsider k.
        c_poly_coa = current_coefs(maxindex, 1:len_block);            
        VsT = ChebyshevDeriv(current_temp, c_poly_coa, low_Tat, high_Tat);
        
        WsT = zeros(1,n);
        for k = 1:length(outsiders)
            cid = outsiders(k);
            idx_start = k*len_block + 1;
            idx_end   = (k+1)*len_block;
            c_poly_out = current_coefs(maxindex, idx_start:idx_end);
            WsT(cid) = ChebyshevDeriv(current_temp, c_poly_out, low_Tat, high_Tat);
        end
    end

    % Compute current-period emissions.
    QV = [(new_alpha(insiders) + lambda.*VsT)./new_beta(insiders)].^(1/(power_b-1));
    QW = [(new_alpha(outsiders) + lambda.*WsT(outsiders))./new_beta(outsiders)].^(1/(power_b-1));

    current_Q = zeros(1, n);        
    current_Q(insiders) = QV;       
    current_Q(outsiders) = QW;
    current_pai = new_alpha.*current_Q - 1/power_b.*new_beta.*current_Q.^power_b;
    current_utility = current_pai - (0.5.*new_gamma.*current_temp.^2 + new_eta.*current_temp);
    

    if allocation_type == "Shapley"
        stable_profit = all_final_profit(maxindex, :);
        stable_state = alstate(maxindex, :);
        stable_coa_profit = sum(stable_state.*stable_profit);
        stable_coa_utility = sum(stable_state.*current_utility);
        stable_country_utility = zeros(1, n);
        for stable_i = 1:n
            if stable_state(stable_i) == 1
                stable_country_utility(stable_i) = stable_coa_utility*stable_profit(stable_i)/stable_coa_profit;
            elseif stable_state(stable_i) == 0
                stable_country_utility(stable_i) = current_utility(stable_i);
            end
        end
        TraceUtility = [TraceUtility; [sum(stable_country_utility), stable_country_utility]];
    else
        TraceUtility = [TraceUtility; [sum(all_final_profit(maxindex, :)), all_final_profit(maxindex, :)]];
    end

    TraceEmission = [TraceEmission; current_Q];
    TraceBenifit = [TraceBenifit; current_pai];
    TraceCoaNum = [TraceCoaNum; numisstable]; 
    if numisstable == 0
        TraceState = [TraceState; allstate(maxindex, :)]; 
        TraceCoa{end+1} = 0;
    else
        TraceState = [TraceState; allstate(maxindex, :)]; 
        TraceCoa{end+1} = isstable; 
    end

    
    % Use annual emissions to update next-period temperature.
    Qall = sum(QV)+sum(QW);
    UpdatedTemp = current_temp + lambda.*Qall;
    TraceTemp = [TraceTemp; UpdatedTemp];

    current_year = current_year + 1;
end
end
