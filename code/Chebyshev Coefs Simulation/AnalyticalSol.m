function paraat2 = AnalyticalSol(alpha, beta, gamma, eta, lambda, r, tipDam, tecrate, lossrate, rm)
% ANALYTICALSOL computes quadratic closed-form value-function parameters.
% The result is used to validate the Chebyshev solution when benefits are quadratic.

% Apply the post-tipping damage multiplier.
alpha1=alpha;
beta1=beta;

gamma1=gamma*tipDam;
eta1=eta*tipDam;

% Number of regions.
n=length(alpha);

lambda=lambda;

r=r;
invbeta1=1./beta1;

% Enumerate every nonempty coalition.
country=1:n;
start=0;
for i=1:n
    num=nchoosek(n,i);
    final=start+num;
    state=nchoosek(country,i);
    statete=zeros(num,n);
    for j=1:num
        for k=1:n
           loc=find(state(j,:)==k);
           if isempty(loc)
               statete(j,k)=0;
           else
               statete(j,k)=1;
           end
        end
    end
    allstate(start+1:final,1)=i;             % Coalition size.
    allstate(start+1:final,2:n+1)=statete;   % Coalition membership indicators.
    start=final;
    clear statete state final loc
end
nn=size(allstate,1);

% Solve the analytical coefficients for the terminal damage state.
gamma=gamma1;
eta=eta1;


paraat2 = zeros(nn,3*n+2);

for i=1:nn
    alpha = alpha1;
    beta = beta1;
    invbeta = invbeta1;
    if i>12
        for j=1:n
            if allstate(i,j+1)==1
                alpha(j)=alpha1(j).*(1+rm(i).*tecrate);
                beta(j)=beta1(j).*(1+rm(i).*tecrate);
                invbeta(j)=1/beta(j);
            else
                alpha(j)=alpha1(j).*(1-rm(i).*lossrate);
                beta(j)=beta1(j).*(1-rm(i).*lossrate);
                invbeta(j)=1/beta(j);
            end
        end
    end
    m=allstate(i,1);
    counsta=allstate(i,2:n+1);  
    ninvbeta=invbeta.*allstate(i,2:n+1);
    ngamma=gamma.*allstate(i,2:n+1);
    neta=eta.*allstate(i,2:n+1);
    suminvbeta=sum(ninvbeta);
    sumgamma=sum(ngamma);
    sumeta=sum(neta);

    newinvbeta=invbeta;
    newgamma=gamma;
    neweta=eta;
    for j=1:n
        if allstate(i,j+1)==1
            newinvbeta(j)=suminvbeta;
            newgamma(j)=sumgamma;
            neweta(j)=sumeta;
        end
    end
    loc1=find(counsta==1);
    loc0=find(counsta==0);
    aa=alpha.*invbeta;
    A=sum(aa);

    options = optimoptions('fsolve', ...
    'Algorithm', 'trust-region-dogleg', ...
    'Display', 'final', ...
    'FunctionTolerance', 1.0000e-06, ...
    'OptimalityTolerance', 1.0000e-09, ...
    'StepTolerance', 1.0000e-06, ...
    'MaxFunctionEvaluations', 1.0e+06,...
    'MaxIterations', 1.0e+06);

    % Solve for the scaled quadratic term because the unscaled root is far from -1.
    u2=fsolve(@(x) funu1(x,n,m,r,newinvbeta,newgamma,counsta,suminvbeta,sumgamma,lambda),-1,options);
    u2=u2/(lambda^2);
    w2 = zeros(1,n);
    for j=1:n
        w2(j)=(lambda^2*u2-0.5*r+sqrt((lambda^2*u2-0.5*r)^2-newinvbeta(j)*newgamma(j)*lambda^2))/(lambda^2*newinvbeta(j));
    end

    bb = zeros(1,n);
    if m<n
        for j=1:n-m
            bb(j)=(lambda^2*w2(loc0(j))*newinvbeta(loc0(j)))/(lambda^2*w2(loc0(j))*newinvbeta(loc0(j))-lambda^2*u2+r);
        end
    end
    BB=sum(bb)+(lambda^2*w2(loc1(1))*newinvbeta(loc1(1)))/(lambda^2*w2(loc1(1))*newinvbeta(loc1(1))-lambda^2*u2+r);

    bbb = zeros(1,n);
    if m<n
        for j=1:n-m
            bbb(j)=newinvbeta(loc0(j))*(lambda*A*w2(loc0(j))-neweta(loc0(j)))/(lambda^2*w2(loc0(j))*newinvbeta(loc0(j))-lambda^2*u2+r);
        end
    end
    BBB=sum(bbb)+newinvbeta(loc1(1))*(lambda*A*w2(loc1(1))-neweta(loc1(1)))/(lambda^2*w2(loc1(1))*newinvbeta(loc1(1))-lambda^2*u2+r);
    u1=BBB/(1-BB);

    w1 = zeros(1,n);
    for j=1:n
        w1(j)=((lambda*A+lambda^2*u1)*w2(j)-neweta(j))/(lambda^2*w2(j)*newinvbeta(j)-lambda^2*u2+r);
    end

    cc = zeros(1,n);
    for j=1:n
        cc(j)=(alpha(j)^2-lambda^2*w1(j)^2)/(2*beta(j));
    end
    ccc=cc.*counsta;
    C=sum(ccc);

    nc = zeros(1,n);
    for j=1:n
        if counsta(j)==1
            nc(j)=C;
        else
            nc(j)=cc(j);
        end
    end

    w0 = zeros(1,n);
    for j=1:n
        w0(j)=(nc(j)+(lambda*A+lambda^2*u1)*w1(j))/r;
    end
    paraat2(i,1:n)=w0;
    paraat2(i,n+1:2*n)=w1;
    paraat2(i,2*n+1:3*n)=w2;
    paraat2(i,3*n+1)=u2;
    paraat2(i,3*n+2)=u1;
    clear A B C loc1 loc0
end

end
