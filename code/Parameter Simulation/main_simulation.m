clc; clear;

disp('Reading data. Please wait...');

% --- 1. Read data using the existing 2005-2105 structure. ---
Output = [];   
Output(1,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','China','B61:AA61');
Output(2,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','US','B61:AA61');
Output(3,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','EU','B61:AA61');
Output(4,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','Japan','B61:AA61');
Output(5,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','Russia','B61:AA61');
Output(6,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','India','B61:AA61');
Output(7,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','MidEast','B61:AA61');
Output(8,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','LatAm','B61:AA61');
Output(9,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','OthAsia','B61:AA61');
Output(10,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','Eurasia','B61:AA61');
Output(11,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','OHI','B61:AA61');
Output(12,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','Africa','B61:AA61');

Emission=[];   
Emission(1,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','China','B70:AA70');
Emission(2,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','US','B70:AA70');
Emission(3,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','EU','B70:AA70');
Emission(4,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','Japan','B70:AA70');
Emission(5,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','Russia','B70:AA70');
Emission(6,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','India','B70:AA70');
Emission(7,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','MidEast','B70:AA70');
Emission(8,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','LatAm','B70:AA70');          
Emission(9,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','OthAsia','B70:AA70');         
Emission(10,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','Eurasia','B70:AA70');        
Emission(11,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','OHI','B70:AA70');
Emission(12,:) = xlsread('COPY_RICE_2010_BAU1.xlsx','Africa','B70:AA70');

CliDamage=[];   
CliDamage(1,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','China','B64:AA64');
CliDamage(2,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','US','B64:AA64');
CliDamage(3,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','EU','B64:AA64');
CliDamage(4,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','Japan','B64:AA64');
CliDamage(5,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','Russia','B64:AA64');
CliDamage(6,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','India','B64:AA64');
CliDamage(7,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','MidEast','B64:AA64');
CliDamage(8,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','LatAm','B64:AA64');
CliDamage(9,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','OthAsia','B64:AA64');
CliDamage(10,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','Eurasia','B64:AA64');
CliDamage(11,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','OHI','B64:AA64');
CliDamage(12,:)=xlsread('COPY_RICE_2010_BAU1.xlsx','Africa','B64:AA64');
Temp = xlsread('COPY_RICE_2010_BAU1.xlsx','US','B81:BI81'); 

% --- 2. Process and interpolate the data. ---
% Interpolate the decadal nodes 1:10:591 to annual nodes 1:591 with interp1.
xp = 1:10:591; 
xq = 1:591;
Temperature = interp1(xp, Temp(1:60), xq, 'linear');

lambda = 0.0021; 
r = 0.03; % Discount rate.
beni_index = 3; % Fit through 2025 using the first three decadal nodes.
dama_index = 11; % Fit through 2105 using the first eleven decadal nodes.

% --- 3. Fit damage-function parameters b1 and b2. ---
dama_power = 2;
DamageFunc = @(b, temp) b(1).*temp + 1/dama_power.*b(2).*temp.^dama_power;
b1 = zeros(1, 12); b2 = zeros(1, 12);
options_lsq = optimoptions('lsqcurvefit', 'Display', 'off'); % Suppress iteration output.

for i = 1:12
    clidamage = CliDamage(i, 1:dama_index);
    temp_local = Temp(1:dama_index);
    b0 = [2, 2];
    [b, ~, ~, ~, ~] = lsqcurvefit(DamageFunc, b0, temp_local, clidamage, [], [], options_lsq);
    b1(i) = b(1);
    b2(i) = b(2);
end


% --- 4. Fit benefit-function parameters a1 and a2. ---
a1 = zeros(1, 12); a2 = zeros(1, 12);
power_b = 4;
Emi = sum(Emission, 1); 
Emi = Emi(1:beni_index);

% Compute discount factors sum1 and sum2 using the original ten-year step.
sum1 = zeros(1, beni_index); sum2 = zeros(1, beni_index);
count = 1;
for t = 0:10:(beni_index-1)*10
    s = t+1 : t+400; 
    sum11 = sum(exp(-r.*(s-t)));
    sum22 = sum(exp(-r.*(s-t)).*Temperature(s));
    sum1(count) = sum11;
    sum2(count) = sum22;
    count = count + 1;
end

options_nlin = optimoptions('lsqnonlin', 'Display', 'off'); 

for i = 1:12
    emission_local = Emission(i, 1:beni_index)'; 
    output_local = Output(i, 1:beni_index)';     
    temp_local = Temp(1:beni_index)';            
    
    data = [temp_local, Emi(:), emission_local, sum1', sum2'];
    
    base_out = output_local(3); 
    base_emi = emission_local(3);
    
    BenefitFunc = @(a) ...
        (base_out/base_emi + (1/power_b) .* a .* base_emi^(power_b-1)) ... 
        - a .* data(:,3).^(power_b-1) ...
        - (lambda.*data(:,4).*b1(i) + lambda.*data(:,5).*b2(i) + lambda^2.*data(:,4).*b2(i).*data(:,2));
    
    a0 = 1; 
    lb = 1e-6;  
    ub = Inf;   
    
    % Solve for beta (a_fit).
    a_fit = lsqnonlin(BenefitFunc, a0, lb, ub, options_nlin);
    
    % Recover alpha (a1) from the fitted beta.
    alpha_fit = base_out/base_emi + (1/power_b) * a_fit * base_emi^(power_b-1);
    
    a1(i) = alpha_fit; 
    a2(i) = a_fit;
end

% =========================================================================
% --- 5. Check and report the fitted parameters. ---
% =========================================================================
region_names = {'China','US','EU','Japan','Russia','India','MidEast','LatAm','OthAsia','Eurasia','OHI','Africa'};
ParamTable = table(region_names', a1', a2', b1', b2', ...
    'VariableNames', {'Region', 'Alpha', 'Beta', 'Damage_b1', 'Damage_b2'});

disp(' ');
disp('======================================================');
disp('--- Final fitted parameters (table view) ---');
disp('======================================================');
disp(ParamTable);

disp('======================================================');
disp('--- Array output for direct copy and paste ---');
disp('======================================================');

% Format arrays with fifteen significant digits.
print_array = @(name, val) fprintf('%s = [%s];\n', name, strjoin(arrayfun(@(x) sprintf('%.15g', x), val, 'UniformOutput', false), ', '));

% Print all four parameters as MATLAB arrays.
print_array('alpha', a1);
print_array('beta ', a2);
print_array('eta  ', b1);
print_array('gamma', b2);
disp(' ');


% power_b = 2;
% r = 0.03;
% alpha = [11.0334657604834, 24.4137502170485, 38.1848898391454, 27.5617657215639, 12.7465818749775, 15.9950834459415, 19.0458980500723, 20.1206158093654, 11.4514633338904, 12.1860214453994, 22.7348070538837, 17.1128807837688];
% beta  = [3.59647186325812, 14.3550920133867, 35.0131670725523, 72.7485888656993, 29.450383576228, 17.2598573581474, 20.4058863223913, 19.5311018716902, 9.39201028873997, 48.2507378968269, 39.1190728962139, 33.4429254138825];
% eta   = [-0.412175122231976, -0.151759148445624, -0.177534583918931, -0.0200964570702076, -0.0108683595826333, -0.298581674277235, -0.245451737021539, -0.136654553215596, -0.332007076279525, -0.0173972126355926, -0.054137778336929, -0.453661142063269];
% gamma = [0.662003682012863, 0.254297190757564, 0.330996542662779, 0.0434024724151156, 0.0205522385825148, 0.452475628970616, 0.379676292534024, 0.211433952358828, 0.446014387923292, 0.0259960421076673, 0.107031472477427, 0.593180583360299];


% SA Benefit Function: Power_b=4
% alpha = [7.05700622763349, 16.217095511988, 25.2264707830856, 18.3640637083939, 8.49296272738169, 10.1422263725386, 11.439598919864, 13.4098802118304, 7.47460587584446, 8.07229151410675, 15.0403198487314, 11.3396886548001];
% beta  = [0.21712379783102, 3.24267031471744, 18.9337845890792, 336.969068051184, 104.41907786884, 10.9507354882195, 10.7048879244921, 12.2278256232086, 3.86011647539209, 490.46788824557, 74.3958617908829, 82.5003535774615];
% eta   = [-0.412175122231976, -0.151759148445624, -0.177534583918931, -0.0200964570702076, -0.0108683595826333, -0.298581674277235, -0.245451737021539, -0.136654553215596, -0.332007076279525, -0.0173972126355926, -0.054137778336929, -0.453661142063269];
% gamma = [0.662003682012863, 0.254297190757564, 0.330996542662779, 0.0434024724151156, 0.0205522385825148, 0.452475628970616, 0.379676292534024, 0.211433952358828, 0.446014387923292, 0.0259960421076673, 0.107031472477427, 0.593180583360299];


% SA Damage Function: Power_b=4
% alpha = [11.0911560026938, 24.4334477845093, 38.2080339653966, 27.564818784605, 12.748058031887, 16.0351187359942, 19.0835420966588, 20.1361386194285, 11.4901467764852, 12.187981523156, 22.7433573609949, 17.1611780186379];
% beta  = [3.63245924021306, 14.3770671782249, 35.0550155658622, 72.7644917087457, 29.4570447929432, 17.3440213237038, 20.478016501184, 19.5603971791762, 9.45034466325734, 48.2656160060983, 39.1466599350829, 33.6199227578724];
% eta   = [0.0932164298414154, 0.0444089624389994, 0.0787061414123233, 0.0137038068850669, 0.00510785474900238, 0.0471784017641833, 0.0449054720590911, 0.0254131756985133, 0.00357494574137659, 0.00246693872559247, 0.0289982175936389, -0.00888560671768104];
% gamma = [0.0639018067569826, 0.0242519204910994, 0.0314351086493576, 0.00409290250638349, 0.00194232703730067, 0.0436288985756741, 0.0365764528363025, 0.0203144127530311, 0.0437667902355845, 0.00250671859919263, 0.0101245830780998, 0.0584308203955825];
