clc; clear;

% ================= Parameter settings =================
start_year = 2025;
end_year = 2100;
years = start_year:end_year;
starttemp = 1.48;
lambda = 0.0021;

rm = GetRatiomatrix;

% Coefficient intervals; keep these consistent with coefficient generation.
Tat_start = 1.48;
Tat_mid = 2;
Tat_end = 4;

% Scenarios for the one-tipping event year.
tipyears = [2060];

nationstr = ["China","US","EU","Japan","Russia","India","MidEast","LatAm","OthAsia","Eurasia","OHI","Africa"];

% r = 0.03;
alpha = [11.0334657604834, 24.4137502170485, 38.1848898391454, 27.5617657215639, 12.7465818749775, 15.9950834459415, 19.0458980500723, 20.1206158093654, 11.4514633338904, 12.1860214453994, 22.7348070538837, 17.1128807837688];
beta  = [3.59647186325812, 14.3550920133867, 35.0131670725523, 72.7485888656993, 29.450383576228, 17.2598573581474, 20.4058863223913, 19.5311018716902, 9.39201028873997, 48.2507378968269, 39.1190728962139, 33.4429254138825];
omega = [0,0,0,0,0,0,0,0,0,0,0,0];
eta   = [-0.412175122231976, -0.151759148445624, -0.177534583918931, -0.0200964570702076, -0.0108683595826333, -0.298581674277235, -0.245451737021539, -0.136654553215596, -0.332007076279525, -0.0173972126355926, -0.054137778336929, -0.453661142063269];
gamma = [0.662003682012863, 0.254297190757564, 0.330996542662779, 0.0434024724151156, 0.0205522385825148, 0.452475628970616, 0.379676292534024, 0.211433952358828, 0.446014387923292, 0.0259960421076673, 0.107031472477427, 0.593180583360299];


% power_b = 4;
% r = 0.03;
% alpha = [7.05700622763349, 16.217095511988, 25.2264707830856, 18.3640637083939, 8.49296272738169, 10.1422263725386, 11.439598919864, 13.4098802118304, 7.47460587584446, 8.07229151410675, 15.0403198487314, 11.3396886548001];
% beta  = [0.21712379783102, 3.24267031471744, 18.9337845890792, 336.969068051184, 104.41907786884, 10.9507354882195, 10.7048879244921, 12.2278256232086, 3.86011647539209, 490.46788824557, 74.3958617908829, 82.5003535774615];
% omega = [0,0,0,0,0,0,0,0,0,0,0,0];
% eta   = [-0.412175122231976, -0.151759148445624, -0.177534583918931, -0.0200964570702076, -0.0108683595826333, -0.298581674277235, -0.245451737021539, -0.136654553215596, -0.332007076279525, -0.0173972126355926, -0.054137778336929, -0.453661142063269];
% gamma = [0.662003682012863, 0.254297190757564, 0.330996542662779, 0.0434024724151156, 0.0205522385825148, 0.452475628970616, 0.379676292534024, 0.211433952358828, 0.446014387923292, 0.0259960421076673, 0.107031472477427, 0.593180583360299];

% power_b = 2; damage function robust test

% % r = 0.03;
% alpha = [11.0217125700442, 24.4102494150984, 38.1809035863921, 27.5612522185444, 12.7463308313856, 15.9864929463784, 19.0382305376104, 20.117811454848, 11.4437114345915, 12.185661618439, 22.7333202784999, 17.103251138652];
% beta  = [3.58914018152911, 14.3511864194563, 35.0059592536064, 72.7459141230516, 29.4492507320434, 17.2417980282816, 20.3911945159857, 19.5258093745488, 9.38032047608133, 48.2480066047555, 39.1142759070802, 33.4076351614725];
% omega = [0,0,0,0,0,0,0,0,0,0,0,0];
% eta   = [0.0932164252108351, 0.044408775698041, 0.0787061375325546, 0.0137038065772475, 0.00510560292221717, 0.0471784017375799, 0.0449054718175873, 0.0254131756824202, 0.00357494574421004, 0.00246670650039902, 0.0289982175873537, -0.00888562880781959];
% gamma = [0.0639018074257909, 0.0242519476057938, 0.0314351092129841, 0.00409290255108765, 0.00194265398285369, 0.0436288985786975, 0.0365764528713273, 0.0203144127553409, 0.0437667902353963, 0.00250675231626072, 0.0101245830791314, 0.0584308236027264];


% Select the profit allocation rule: Gamma, Shapley, or NoTransfer.
allocation_type = "Shapley";


% ================= Build coalition-state matrix =================
n = length(nationstr);
country = 1:n;
allstate = zeros(2^n-1, n+1);
start = 0;
for i = 1:n
    num = nchoosek(n, i);
    final = start + num;
    state = nchoosek(country, i);
    statete = zeros(num, n);
    for j = 1:num
        statete(j, state(j, :)) = 1;
    end
    allstate(start+1:final, 1) = i;
    allstate(start+1:final, 2:n+1) = statete;
    start = final;
end
alstate = allstate(:, 2:n+1);

% Locate the leader index.
first_one_indices = zeros(size(alstate, 1), 1);
for i = 1:size(alstate, 1)
    idx = find(alstate(i, :) == 1, 1);
    if ~isempty(idx)
        first_one_indices(i) = idx;
    end
end
first_one_indices = first_one_indices';


% ================= Load coefficient datasets =================
% This naming pattern matches the output of Once_Tipping_Chebyshev.m.
if allocation_type == "NoTransfer"
    folder = 'One Tipping Chebyshev Coefs/One Tipping ChebyEval Results NT Power_b_2';
    search_prefix = 'coefsNT_onetipping_*.mat';
    file_map = {
        'coefsNT_onetipping_',       'coefs_NT_1tipped';
        'coefsNT_notipping_lowT_',   'coefs_NT_0tipped_lowTemp';
        'coefsNT_notipping_highT_',  'coefs_NT_0tipped_highTemp'
    };
else
    folder = 'One Tipping Chebyshev Coefs/One Tipping ChebyEval Results Connection Power_b_2';
    search_prefix = 'coefs1_onetipping_*.mat';
    file_map = {
        'coefs1_onetipping_',       'coefs_1tipped';
        'coefs1_notipping_lowT_',   'coefs_0tipped_lowTemp';
        'coefs1_notipping_highT_',  'coefs_0tipped_highTemp'
    };
end

files = dir(fullfile(folder, search_prefix));

if isempty(files)
    error('No benchmark data found. Check whether "%s" contains files matching "%s".', folder, search_prefix);
end

DataSets = struct();
fprintf('Loading %d benchmark datasets...\n', length(files));
for i = 1:length(files)
    base_name = files(i).name;
    prefix_base = file_map{1, 1};

    suffix = strrep(base_name, prefix_base, '');

    % Parse tip, tecrate, lossrate, power_b, and maxdegree.
    p = sscanf(suffix, '%f_%f_%f_%f_%f_%f.mat');
    DataSets(i).tip = p(1);
    DataSets(i).tecrate = p(2);
    DataSets(i).lossrate = p(3);
    DataSets(i).power_b = p(4);
    DataSets(i).maxdegree = p(5);
    DataSets(i).r = p(6);
    DataSets(i).alpha = alpha;
    DataSets(i).beta  = beta;

    DataSets(i).filename_base = base_name;
    DataSets(i).suffix_clean = strrep(suffix, '.mat', '');

    % Load the three related coefficient files.
    for k = 1:size(file_map, 1)
        prefix = file_map{k, 1};
        var_name = file_map{k, 2};
        f_path = fullfile(folder, [prefix, suffix]);

        if exist(f_path, 'file')
            tmp = load(f_path);
            if isfield(tmp, var_name)
                DataSets(i).(var_name) = tmp.(var_name);
            else
                vars = fieldnames(tmp);
                DataSets(i).(var_name) = tmp.(vars{1});
            end
        else
            DataSets(i).(var_name) = [];
        end
    end
end


% ================= Run simulations =================
saveDir = strcat('Results of SA Con Ell');
mkdir(saveDir);
hWaitBar = waitbar(0, 'Processing...');

for i = 1:length(DataSets)
    try
        % Extract scenario parameters.
        power_b   = DataSets(i).power_b;
        tecrate   = DataSets(i).tecrate;
        lossrate  = DataSets(i).lossrate;
        maxdegree = DataSets(i).maxdegree;
        r = DataSets(i).r;
        disp(DataSets(i))
        alpha = DataSets(i).alpha;
        beta = DataSets(i).beta;
        tip = DataSets(i).tip;
        file_suffix = DataSets(i).suffix_clean;

        outputfile = strcat(saveDir, "/Year_2025_Stable_Coalition_Result_Onetipping_", ...
            allocation_type, "_", "_r_", num2str(r), "_Hazard_Rate.xlsx");

        if allocation_type == "NoTransfer"
            coefs_1tipped          = DataSets(i).coefs_NT_1tipped;
            coefs_0tipped_lowTemp  = DataSets(i).coefs_NT_0tipped_lowTemp;
            coefs_0tipped_highTemp = DataSets(i).coefs_NT_0tipped_highTemp;
        else
            coefs_1tipped          = DataSets(i).coefs_1tipped;
            coefs_0tipped_lowTemp  = DataSets(i).coefs_0tipped_lowTemp;
            coefs_0tipped_highTemp = DataSets(i).coefs_0tipped_highTemp;
        end

        if isempty(coefs_1tipped) || isempty(coefs_0tipped_lowTemp) || isempty(coefs_0tipped_highTemp)
            warning('Dataset %d (%s) is missing required coefficients and will be skipped.', i, DataSets(i).filename_base);
            continue;
        end

        for j = 1:length(tipyears)
            tip_year = tipyears(j);

            [TraceTemp, TraceState, TraceUtility, TraceCoaNum, TraceCoa, TraceEmission, TraceBenifit] = ...
                Once_Tipping_Allocation(allocation_type, start_year, end_year, tip_year, Tat_start, Tat_mid, Tat_end, ...
                coefs_1tipped, coefs_0tipped_lowTemp, coefs_0tipped_highTemp, ...
                power_b, maxdegree, alpha, beta, gamma, eta, r, tip, allstate, alstate, starttemp, lambda, first_one_indices, tecrate, lossrate, rm);

            TraceTemp = TraceTemp(1:end-1);

            sheetname = file_suffix;
            if length(tipyears) > 1
                sheetname = strcat(sheetname, '_Y', num2str(tip_year));
            end
            if length(sheetname) > 31
                sheetname = strrep(sheetname, '0.', '.');
                if length(sheetname) > 31
                    sheetname = sheetname(1:31);
                end
            end

            writematrix(["Year", "Temp"], outputfile, 'Sheet', sheetname, 'Range', 'A1', 'WriteMode', 'overwrite');
            writematrix(["Size of Coalition", nationstr], outputfile, 'Sheet', sheetname, 'Range', 'C1');

            profit_headers = "Utility of " + nationstr;
            writematrix(["Utility of All", profit_headers], outputfile, 'Sheet', sheetname, 'Range', 'P1');

            emission_headers = "Emission of " + nationstr;
            writematrix(emission_headers, outputfile, 'Sheet', sheetname, 'Range', 'AC1');

            benifit_headers = "Benifit of " + nationstr;
            writematrix(benifit_headers, outputfile, 'Sheet', sheetname, 'Range', 'AO1');

            writematrix(["Num of Coalition", "Index of Coalition"], outputfile, 'Sheet', sheetname, 'Range', 'BA1');

            % ---------------------- Write output data ----------------------
            Data_AB = [years(1:length(TraceTemp))', TraceTemp];
            writematrix(Data_AB, outputfile, 'Sheet', sheetname, 'Range', 'A2');
            writematrix(TraceState, outputfile, 'Sheet', sheetname, 'Range', 'C2');
            writematrix(TraceUtility, outputfile, 'Sheet', sheetname, 'Range', 'P2');
            writematrix(TraceEmission, outputfile, 'Sheet', sheetname, 'Range', 'AC2');
            writematrix(TraceBenifit, outputfile, 'Sheet', sheetname, 'Range', 'AO2');

            writematrix(TraceCoaNum, outputfile, 'Sheet', sheetname, 'Range', 'BA2');

            for k = 1:length(TraceCoa)
                writematrix(TraceCoa{k}', outputfile, 'Sheet', sheetname, 'Range', strcat("BB", num2str(k+1)));
            end
        end

    catch ME
        disp(['Error processing Data Set index ' num2str(i) ': ' ME.message]);
    end
    waitbar(i/length(DataSets), hWaitBar, sprintf('Processing %d / %d...', i, length(DataSets)));
end
close(hWaitBar);
disp('All simulations completed.');
