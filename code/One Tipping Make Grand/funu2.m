function f=funu2(w,A,B,C,D,E,m,counsta,invbeta,lambda,newL)
r=0.05;
n=3;

loc1=find(counsta==1);
loc0=find(counsta==0);

% Reshape the coefficient vector into value-function blocks.
for i = 1:n-m+1
    for j = 1:3
        Wmatrix(i,j)=w((i-1)*3+j);
    end
end

% Define U = V/beta + sum(W/beta) and evaluate its derivative.
for i = 1:2
    if length(loc0)>=1
        for j=1:length(loc0)
            W12(j)=Wmatrix(j+1,i+1).*invbeta(loc0(j));
        end
        sumW12(i)=sum(W12);
    else
        sumW12(i)=0;
    end
    sumW(i)=-2*A(loc1(1))*Wmatrix(1,i+1)+sumW12(i);
end


f(1) = -0.5*r*Wmatrix(1,3)+lambda^2*A(loc1(1))*Wmatrix(1,3)^2+D(loc1(1))+Wmatrix(1,3)*lambda^2*sumW(2);
f(2) = -r*Wmatrix(1,2)+Wmatrix(1,2)*lambda^2*sumW(2)+2*A(loc1(1))*lambda^2*Wmatrix(1,2)*Wmatrix(1,3)+Wmatrix(1,3)*lambda*B(loc1(1))...
    +Wmatrix(1,3)*lambda^2*sumW(1)+E(loc1(1));
f(3) = -r*Wmatrix(1,1)+C(loc1(1))+lambda^2*A(loc1(1))*Wmatrix(1,2)^2-newL(loc1(1))+Wmatrix(1,2)*(lambda*B(loc1(1))...
    +lambda^2*sumW(1));

if length(loc0)>=1
    for j=1:length(loc0)
        f(3*j+1) = -0.5*r*Wmatrix(j,3)+lambda^2*A(loc0(j))*Wmatrix(j,3)^2+D(loc0(j))+Wmatrix(j,3)*lambda^2*sumW(2);
        f(3*j+2) = -r*Wmatrix(j,2)+Wmatrix(j,2)*lambda^2*sumW(2)+2*A(loc0(j))*lambda^2*Wmatrix(j,2)*Wmatrix(j,3)+Wmatrix(j,3)*lambda*...
            B(loc0(j))+Wmatrix(j,3)*lambda^2*sumW(1)+E(loc0(j));
        f(3*j+3) = -r*Wmatrix(j,1)+C(loc0(j))+lambda^2*A(loc0(j))*Wmatrix(j,2)^2-newL(loc0(j))+Wmatrix(j,2)*(lambda*B(loc0(j))...
            +lambda^2*sumW(1));
    end
end
end
    

