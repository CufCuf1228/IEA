function fval = ChebyEval(x, coef, a, b)

% CHEBYEVAL evaluates a univariate Chebyshev approximation on [a, b].
% It returns one approximated value for every element of x.
%
% Author: Yongyang Cai, The Ohio State University
% Date: September 30, 2019
% All copyrights reserved.
%
% Any use of the materials in this code file must cite the following paper:
% Cai, Yongyang, and Kenneth L. Judd (2014). Advances in numerical dynamic 
% programming and new applications. Chapter 8 in: Handbook of Computational 
% Economics, Vol. 3, ed. by Karl Schmedders and Kenneth L. Judd, Elsevier.

% Normalize the evaluation points and build the basis by recurrence.
d = length(coef) - 1;
fval = zeros(size(x));
z = 2*(x-a)/(b-a) - 1;

T = zeros(size(coef));
for i = 1:length(x)    
    T(1) = 1;
    T(2) = z(i);
    for j = 2:d
        T(j+1) = 2*z(i)*T(j) - T(j-1);
    end
    
    % Evaluate the polynomial at the current point.
    fval(i) = sum(T.*coef);
end

end
