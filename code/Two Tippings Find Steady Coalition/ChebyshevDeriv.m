function deriv = ChebyshevDeriv(x, coeffs, low_Tat, high_Tat)
    a = low_Tat; b = high_Tat;
    z = (2 * x - (a + b)) / (b - a);
    n = length(coeffs) - 1;
    c_deriv = zeros(n, 1);
    if n > 0
        c_deriv(n) = 2 * n * coeffs(n+1);
        if n > 1
            c_deriv(n-1) = 2 * (n-1) * coeffs(n);
        end
        for k = n-2:-1:1
            c_deriv(k) = c_deriv(k+2) + 2 * k * coeffs(k+1);
        end
        c_deriv(1) = c_deriv(1) / 2;
        dd_k = 0; dd_kp1 = 0;
        n_d = length(c_deriv) - 1;
        for k = n_d:-1:1
            dd_kp2 = dd_kp1;
            dd_kp1 = dd_k;
            dd_k = 2 * z * dd_kp1 - dd_kp2 + c_deriv(k+1);
        end
        Val_dz = z * dd_k - dd_kp1 + c_deriv(1);
    else
        Val_dz = 0;
    end
    dz_dx = 2 / (b - a);
    deriv = Val_dz * dz_dx;
end