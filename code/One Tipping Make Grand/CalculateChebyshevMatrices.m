function [T, dT, z, dz] = CalculateChebyshevMatrices(degree, Tat0, Tat)

    Tl = -cos((2*[1:degree+1]'-1)*pi/(2*(degree+1)));
    z = (Tl+1)*(Tat-Tat0)/2+Tat0;
    
    dz = 2/(Tat-Tat0);
    Nnode = length(z);
    
    T = zeros(Nnode,degree+1);
    dT = zeros(Nnode,degree+1);
    
    for k = 1:Nnode
        T(k,1) = 1;
        T(k,2) = Tl(k);
        for j = 2:degree
            T(k,j+1) = 2*Tl(k)*T(k,j) - T(k,j-1);
        end
        
        dT(k,1) = 0;
        dT(k,2) = dz;
        for j = 2:degree
            dT(k,j+1) = 2*dz*T(k,j)+2*Tl(k)*dT(k,j)-dT(k,j-1);
        end
    end
end

