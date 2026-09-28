function [ratiomatrix] = GetRatiomatrix()


% Region order.
nationstr = ["China","US","EU","Japan","Russia","India","MidEast","LatAm","OthAsia","Eurasia","OHI","Africa"];

% Baseline 2005 GDP and regional shares.
GDP_2005 = [5.3332, 12.3979, 13.0311, 3.8703, 1.6980, 2.4408, 3.4801, 4.5585, 2.6192, 2.5769, 3.8420, 1.3005];
GDP_Rate = GDP_2005./sum(GDP_2005);

% Enumerate every nonempty coalition.
n=12;
country=1:n;
start=0;
for i=1:n
    num(i)=nchoosek(n,i);
    final=start+num(i);
    state=nchoosek(country,i);
    for j=1:num(i)
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

alstate = allstate(:,2:13);

ratiomatrix = ones(nn,1);

for i = 1:4095
    if i <= 12
        ratiomatrix(i) = 0;
    else
        ratiomatrix(i) = sum(alstate(i,:).*GDP_Rate);
    end
end
    
    







