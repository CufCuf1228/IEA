clc; clear;

% ================= Parameter settings =================
% beni_type is either "Connection" or "Sanction".
beni_type = "Connection";

% One-tipping damage scenarios.
% Multiple rows may be supplied, for example [0.5; 1; 1.5].
tip_scenarios = [
    1
];

% Scenarios for the one-tipping event year.
tipyear_scenarios = [
    2060
];

rm_full = GetRatiomatrix();
rm = rm_full(4083:end, :);   % Keep n single-region exits plus the grand coalition.

power_b = 2;
Tat_start = 1.48;
Tat_mid = 2;
Tat_end = 4;

nationstr = ["China","US","EU","Japan","Russia","India","MidEast","LatAm","OthAsia","Eurasia","OHI","Africa"];

r = 0.03;

alpha = [11.0334657604834, 24.4137502170485, 38.1848898391454, 27.5617657215639, 12.7465818749775, 15.9950834459415, 19.0458980500723, 20.1206158093654, 11.4514633338904, 12.1860214453994, 22.7348070538837, 17.1128807837688];
beta  = [3.59647186325812, 14.3550920133867, 35.0131670725523, 72.7485888656993, 29.450383576228, 17.2598573581474, 20.4058863223913, 19.5311018716902, 9.39201028873997, 48.2507378968269, 39.1190728962139, 33.4429254138825];
eta   = [-0.412175122231976, -0.151759148445624, -0.177534583918931, -0.0200964570702076, -0.0108683595826333, -0.298581674277235, -0.245451737021539, -0.136654553215596, -0.332007076279525, -0.0173972126355926, -0.054137778336929, -0.453661142063269];
gamma = [0.662003682012863, 0.254297190757564, 0.330996542662779, 0.0434024724151156, 0.0205522385825148, 0.452475628970616, 0.379676292534024, 0.211433952358828, 0.446014387923292, 0.0259960421076673, 0.107031472477427, 0.593180583360299];

chi1 = 0.007;
lambda = 0.0021;

maxdegree = 6;
Year = 2025:1:2100;

current_rate = 0.001;
loop_step = 0.00001;
max_rate = 1.0;

outputfile = ['GrandCoalitionTrace_Once_', char(beni_type), '.xlsx'];

% ================= Loop 1: tipping-damage scenarios =================
for t_idx = 1:size(tip_scenarios, 1)

    tip = tip_scenarios(t_idx, :);

    % ================= Loop 2: tipping-year scenarios =================
    for ty_idx = 1:size(tipyear_scenarios, 1)

        tipyear = tipyear_scenarios(ty_idx, :);
        fprintf('Processing: Tip=%.2f, TipYear=%d...\n', tip, tipyear);

        TraceTemp = 1.48;
        TraceRate = [];
        TraceValueFunction = [];
        TraceUtility = [];
        current_rate = 0.001;

        % ================= Annual simulation loop =================
        for year = Year
            temp = TraceTemp(end);

            % ============================================================
            % 1. Find the minimum rate that keeps the grand coalition stable.
            % ============================================================

            rate_low = 0;
            rate_high = max(current_rate, loop_step);

            [stable_low, ~] = EvaluateGrandCoalitionRate( ...
                rate_low, beni_type, year, temp, tipyear, tip, ...
                power_b, Tat_start, Tat_mid, Tat_end, alpha, beta, ...
                gamma, eta, chi1, lambda, r, maxdegree, rm);

            if stable_low
                current_rate = 0;
            else
                stable_high = false;
                while ~stable_high && rate_high <= max_rate
                    [stable_high, ~] = EvaluateGrandCoalitionRate( ...
                        rate_high, beni_type, year, temp, tipyear, tip, ...
                        power_b, Tat_start, Tat_mid, Tat_end, alpha, beta, ...
                        gamma, eta, chi1, lambda, r, maxdegree, rm);

                    if ~stable_high
                        rate_high = rate_high * 2;
                    end
                end

                if rate_high > max_rate
                    warning('Year %d: cannot find a stable rate below max_rate = %.6f. Use max_rate.', ...
                        year, max_rate);
                    current_rate = max_rate;
                else
                    while rate_high - rate_low > loop_step
                        rate_mid = 0.5 * (rate_low + rate_high);

                        [stable_mid, ~] = EvaluateGrandCoalitionRate( ...
                            rate_mid, beni_type, year, temp, tipyear, tip, ...
                            power_b, Tat_start, Tat_mid, Tat_end, alpha, beta, ...
                            gamma, eta, chi1, lambda, r, maxdegree, rm);

                        if stable_mid
                            rate_high = rate_mid;
                        else
                            rate_low = rate_mid;
                        end
                    end
                    current_rate = rate_high;
                end
            end

            TraceRate = [TraceRate, current_rate];

            % ============================================================
            % 2. Recompute with the final rate and store value functions and utility.
            % ============================================================

            [~, evalResult] = EvaluateGrandCoalitionRate( ...
                current_rate, beni_type, year, temp, tipyear, tip, ...
                power_b, Tat_start, Tat_mid, Tat_end, alpha, beta, ...
                gamma, eta, chi1, lambda, r, maxdegree, rm);

            ValueFunction = evalResult.inprofit;
            Utility = evalResult.utility;

            TraceValueFunction = [TraceValueFunction, ValueFunction];
            TraceUtility = [TraceUtility, Utility];

            coa_coefs = evalResult.coa_coefs;
            low_Tat = evalResult.low_Tat;
            high_Tat = evalResult.high_Tat;
            grand_row = evalResult.grand_row;

            % ============================================================
            % 3. Update temperature at year end.
            % ============================================================

            VsT = ChebyshevDeriv(temp, coa_coefs, low_Tat, high_Tat);

            beni_type_key = lower(char(beni_type));
            if strcmp(beni_type_key, 'connection')
                final_conrate = TraceRate(end);
                Q = ((alpha .* (1 + rm(grand_row) .* final_conrate) + lambda .* VsT) ./ ...
                    (beta  .* (1 + rm(grand_row) .* final_conrate))).^(1/(power_b-1));
            elseif strcmp(beni_type_key, 'sanction')
                Q = ((alpha + lambda .* VsT) ./ beta).^(1/(power_b-1));
            else
                error('Unknown beni_type. Use "Connection" or "Sanction".');
            end

            Qall = sum(Q);
            UpdatedTemp = temp + lambda .* Qall;
            TraceTemp = [TraceTemp, UpdatedTemp];

            fprintf('Year %d: Temp=%.6f, Rate=%.6f, Stable=%d, ValueFunction=%.6f, Utility=%.6f\n', ...
                year, temp, current_rate, evalResult.stable, ValueFunction, Utility);
        end

        % ================= Save the current scenario =================
        TraceTemp = TraceTemp(1:length(Year));

        sheetname = ['T_', num2str(tip), '_Y_', num2str(tipyear)];

        if length(sheetname) > 31
            sheetname = strrep(sheetname, '0.', '.');
            if length(sheetname) > 31
                sheetname = sheetname(1:31);
            end
        end

        beni_type_key = lower(char(beni_type));
        if strcmp(beni_type_key, 'connection')
            rate_header = "Conrate";
        elseif strcmp(beni_type_key, 'sanction')
            rate_header = "Lossrate";
        else
            error('Unknown beni_type. Use "Connection" or "Sanction".');
        end

        headers = ["Year", "Temp", rate_header, "ValueFunction", "Utility"];
        data = [Year', TraceTemp', TraceRate', TraceValueFunction', TraceUtility'];

        try
            writematrix(headers, outputfile, 'Sheet', sheetname, 'Range', 'A1');
            writematrix(data, outputfile, 'Sheet', sheetname, 'Range', 'A2');
        catch ME
            warning(['Failed to write Excel output (sheet: ', sheetname, '): ', ME.message]);
        end
    end
end

disp(['All simulations completed. Results saved to ', outputfile]);
