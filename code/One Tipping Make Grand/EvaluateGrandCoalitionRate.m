function [stable, evalResult] = EvaluateGrandCoalitionRate(rate, beni_type, year, temp, tipyear, tip, ...
    power_b, Tat_start, Tat_mid, Tat_end, alpha, beta, gamma, eta, ...
    chi1, lambda, r, maxdegree, rm)
% Evaluate whether the grand coalition is stable under the Future value-function criterion.
% One-tipping version. This function contains no Now/instantaneous-utility stability calculation.
% It additionally reports current-period utility, defined as pai - damage.

beni_type_key = lower(char(beni_type));
if strcmp(beni_type_key, 'connection')
    conrate = rate;
    lossrate = 0;
elseif strcmp(beni_type_key, 'sanction')
    conrate = 0;
    lossrate = rate;
else
    error('Unknown beni_type. Use "Connection" or "Sanction".');
end

% 1. Compute coefficients for the grand coalition and n single-region exits.
[coa_state, coefs_1tipped, coefs_0tipped_lowTemp, coefs_0tipped_highTemp] = ...
    Once_Tipping_Chebyshev_for_Grand(power_b, Tat_start, Tat_mid, Tat_end, ...
    alpha, beta, gamma, eta, chi1, lambda, r, maxdegree, ...
    tip, conrate, lossrate, rm);

n = size(coa_state, 1) - 1;
grand_row = n + 1;

% 2. Select the tipping-state coefficients and damage parameters for this year and temperature.
if year >= tipyear
    coefs = coefs_1tipped;
    low_Tat = Tat_start;
    high_Tat = Tat_end;
    tipping_state = 1;
    new_gamma = (1 + tip) * gamma;
    new_eta   = (1 + tip) * eta;
else
    if temp < Tat_mid
        coefs = coefs_0tipped_lowTemp;
        low_Tat = Tat_start;
        high_Tat = Tat_mid;
    else
        coefs = coefs_0tipped_highTemp;
        low_Tat = Tat_mid;
        high_Tat = Tat_end;
    end
    tipping_state = 0;
    new_gamma = gamma;
    new_eta   = eta;
end

% 3. Future value-function criterion:
%    External value is the sum of outsider values across the n exit cases.
%    Internal value is the grand-coalition value.
outprofit = 0;
for k = 1:n
    country_coefs = coefs(k, (maxdegree+1)+1 : 2*(maxdegree+1));
    outprofit = outprofit + ChebyEval(temp, country_coefs, low_Tat, high_Tat);
end

coa_coefs = coefs(grand_row, 1:maxdegree+1);
inprofit = ChebyEval(temp, coa_coefs, low_Tat, high_Tat);

stable = (outprofit <= inprofit);

% 4. Compute current grand-coalition utility as profit minus damage.
%    This value is recorded for the trajectory and is not the stability criterion.
VsT = ChebyshevDeriv(temp, coa_coefs, low_Tat, high_Tat);

new_alpha = alpha;
new_beta  = beta;
if strcmp(beni_type_key, 'con')
    new_alpha = alpha .* (1 + rm(grand_row) .* conrate);
    new_beta  = beta  .* (1 + rm(grand_row) .* conrate);
elseif strcmp(beni_type_key, 'sanction')
    % The grand coalition has no outsiders, so sanctions do not change its alpha or beta.
    new_alpha = alpha;
    new_beta  = beta;
end

Q = ((new_alpha + lambda .* VsT) ./ new_beta).^(1/(power_b-1));
pai = new_alpha .* Q - 1/power_b .* new_beta .* Q.^power_b;
damage = 0.5 .* new_gamma .* temp.^2 + new_eta .* temp;
utility_country = pai - damage;
utility_sum = sum(utility_country);

% 5. Return intermediate results for temperature updates and trajectory storage.
evalResult = struct();
evalResult.stable = stable;
evalResult.outprofit = outprofit;
evalResult.inprofit = inprofit;
evalResult.utility = utility_sum;
evalResult.utility_country = utility_country;
evalResult.pai = pai;
evalResult.damage = damage;
evalResult.Q = Q;
evalResult.coa_coefs = coa_coefs;
evalResult.low_Tat = low_Tat;
evalResult.high_Tat = high_Tat;
evalResult.grand_row = grand_row;
evalResult.tipping_state = tipping_state;
evalResult.conrate = conrate;
evalResult.lossrate = lossrate;
evalResult.coa_state = coa_state;
evalResult.current_coefs = coefs;
evalResult.new_gamma = new_gamma;
evalResult.new_eta = new_eta;

end
