% MAIN_TEST_VALUE_FUNCTION_NT derives no-transfer individual value functions.
% It loads benchmark one-tipping coalition coefficients and saves NT decompositions.

% Scenario and temperature-domain settings.
tip = [1];
con = [0.006];
lossrate = 0;
rm = GetRatiomatrix;

Tat_start = 1.48;
Tat_mid = 2;
Tat_end = 4;
region_names = ["China","US","EU","Japan","Russia","India","MidEast","LatAm","OthAsia","Eurasia","OHI","Africa"];

% Calibrated 2025 regional parameters.
power_b = 2;
r = 0.03;
alpha = [11.0334657604834, 24.4137502170485, 38.1848898391454, 27.5617657215639, 12.7465818749775, 15.9950834459415, 19.0458980500723, 20.1206158093654, 11.4514633338904, 12.1860214453994, 22.7348070538837, 17.1128807837688];
beta  = [3.59647186325812, 14.3550920133867, 35.0131670725523, 72.7485888656993, 29.450383576228, 17.2598573581474, 20.4058863223913, 19.5311018716902, 9.39201028873997, 48.2507378968269, 39.1190728962139, 33.4429254138825];
eta   = [-0.412175122231976, -0.151759148445624, -0.177534583918931, -0.0200964570702076, -0.0108683595826333, -0.298581674277235, -0.245451737021539, -0.136654553215596, -0.332007076279525, -0.0173972126355926, -0.054137778336929, -0.453661142063269];
gamma = [0.662003682012863, 0.254297190757564, 0.330996542662779, 0.0434024724151156, 0.0205522385825148, 0.452475628970616, 0.379676292534024, 0.211433952358828, 0.446014387923292, 0.0259960421076673, 0.107031472477427, 0.593180583360299];
% Numerical approximation settings.
chi1 = 0.007;
lambda = 0.0021;
maxdegree = 6;


% Process every requested tipping-loss and technology-rate combination.
for i = 1:length(tip)
    for j = 1:length(con)

        % Match the suffix used by the benchmark one-tipping solver.
        mystr = strcat(num2str(tip(i)),'_',num2str(con(j)),'_',num2str(lossrate),'_',num2str(power_b),'_',num2str(maxdegree),'_',num2str(r));

        % Use the exact output directory created by Once_Tipping_Chebyshev.
        if power_b == 2
            saveDir = fullfile('.', 'One Tipping Chebyshev Coefs', ...
                'One Tipping ChebyEval Results SA Benchmark');
        else
            saveDir = fullfile('.', 'One Tipping Chebyshev Coefs', ...
                strcat('One Tipping ChebyEval Results SA Benchmark', num2str(power_b)));
        end

        % Keep NT results in a separate, consistently named folder.
        saveDir_NT = fullfile('.', 'One Tipping Chebyshev Coefs', ...
            strcat('One Tipping ChebyEval Results NT Power_b_', num2str(power_b)));
        if ~exist(saveDir_NT, 'dir')
            mkdir(saveDir_NT);
        end

        disp(['Processing combination: tip=', num2str(tip(i)), ', con=', num2str(con(j))]);

        % Load the coalition-level coefficients for all one-tipping states.
        try
            load(fullfile(saveDir, strcat('coefs1_onetipping_', mystr, '.mat')), 'coefs_1tipped');
            load(fullfile(saveDir, strcat('coefs1_notipping_lowT_', mystr, '.mat')), 'coefs_0tipped_lowTemp');
            load(fullfile(saveDir, strcat('coefs1_notipping_highT_', mystr, '.mat')), 'coefs_0tipped_highTemp');
        catch
            warning('Original coefficient files were not found in %s for suffix %s. Skipping this combination.', saveDir, mystr);
            continue;
        end

        % Recover the no-transfer individual value functions.
        [coefs_NT_1tipped, coefs_NT_0tipped_lowTemp, coefs_NT_0tipped_highTemp] = ...
            Once_Tipping_Chebyshev_NT(power_b, Tat_start, Tat_mid, Tat_end, alpha, beta, gamma, eta, chi1, lambda, r, maxdegree, tip(i), con(j), lossrate, rm, ...
            coefs_1tipped, coefs_0tipped_lowTemp, coefs_0tipped_highTemp);

        % Save one NT coefficient matrix per tipping-temperature state.
        save(fullfile(saveDir_NT, strcat('coefsNT_onetipping_', mystr, '.mat')), 'coefs_NT_1tipped');
        save(fullfile(saveDir_NT, strcat('coefsNT_notipping_lowT_', mystr, '.mat')), 'coefs_NT_0tipped_lowTemp');
        save(fullfile(saveDir_NT, strcat('coefsNT_notipping_highT_', mystr, '.mat')), 'coefs_NT_0tipped_highTemp');

        disp(['NT individual value coefficients computed and saved for tip=', ...
            num2str(tip(i)), ', con=', num2str(con(j)), '.']);
        disp('--------------------------------------------------');
    end
end

disp('All one-tipping NT cases are complete.');
