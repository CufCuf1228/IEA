function fval = ChebyEval(x, coef, a, b)

%ChebyEval evaluates univariate Chebyshev approximation
%   The function takes as input data vector x where x is in the 
%   approximation domain [a, b]; coefs are the coefficients of the 
%   Chebyshev polynomial approximation.
%   The function returns a vector of the same length as x containing 
%   the function evaluation corresponding to each x.
%
% Author: Yongyang Cai, The Ohio State University
% Date: September 30, 2019
% All copyrights reserved.
%
% Any use of the materials in this code file must cite the following paper:
% Cai, Yongyang, and Kenneth L. Judd (2014). Advances in numerical dynamic 
% programming and new applications. Chapter 8 in: Handbook of Computational 
% Economics, Vol. 3, ed. by Karl Schmedders and Kenneth L. Judd, Elsevier.

% the degree of the Chebyshev polynomial
d = length(coef) - 1;

% initialization
fval = zeros(size(x));

% normalizes x vector
z = 2*(x-a)/(b-a) - 1;

T = zeros(size(coef));
for i = 1:length(x)    
    T(1) = 1;
    T(2) = z(i);
    for j = 2:d
        T(j+1) = 2*z(i)*T(j) - T(j-1);
    end
    
    % Evaluates polynomial
    fval(i) = sum(T.*coef);
end

end