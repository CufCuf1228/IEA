function y=funu1(x,n,m,r,newinvbeta,newgamma,counsta,suminvbeta,sumgamma,lambda)
sumsqua=0;
for i=1:n
    sumsqua=sumsqua+sqrt(((x-0.5*r)^2)-(lambda^2*newgamma(i)*newinvbeta(i)))*(1-counsta(i));
end
y=(n-m)*x-((n-m+1)*0.5*r-sumsqua-sqrt(((x-0.5*r)^2)-(lambda^2*suminvbeta*sumgamma)));