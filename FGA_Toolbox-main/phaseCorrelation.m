function [corrMat, assembly_contents] = phaseCorrelation(tempData, tempLoc, varargin)
% PHASECORRELATION doc string

% Try to calculate the phase of the trace
[totTrace, timeFinal] = size(tempData);
phase = 2*pi*rand(totTrace, timeFinal);
for trace = 1:totTrace
    spikes = tempLoc{trace};
    if ~isempty(spikes)
        k = 0;
        for t = 1:timeFinal
            if any(t==spikes)
                k = k+1;
            end
            if k == 0
                phase(trace,t) = 2*pi*(t-spikes(1)) / (spikes(1));
            elseif k < numel(spikes)
                phase(trace,t) = 2*pi*(t-spikes(k)) / (spikes(k+1) - spikes(k)) + 2*pi*k;
            end
        end
    end
end
% Calculate the correlation matrix of the phases
corrMat = zeros(totTrace);
for c1 = 1:totTrace
    for c2 = 1:totTrace
        if ~isempty(tempLoc{c1}) && ~isempty(tempLoc{c2})
            deltaphi = mod(phase(c1,:)-phase(c2,:),2*pi);
            corrMat(c1,c2) = sqrt(mean(cos(deltaphi))^2 + mean(sin(deltaphi))^2);
            corrMat(c2,c1) = corrMat(c1,c2);
        end
    end
end
% Calculate the eigenvalues
[eigV, eigD] = eig(corrMat);
eigD = diag(eigD);

nCluster = sum(eigD >= 0.1);
PI = zeros(totTrace, nCluster);
i_cluster = find(eigD >= 0.1);

for k=1:nCluster
    lambda = eigD(i_cluster(k));
    vk = eigV(:,i_cluster(k));
    PI(:,k) =lambda*vk.^2;
end
[~,idx] = max(PI,[],2);
Cluster_size = zeros(size(PI,2),1);
for i=1:length(Cluster_size)
    Cluster_size(i) = nnz(idx==i);
end
Nclusters = nnz(Cluster_size>2);
idx = find(Cluster_size<=2);
PI(:,idx) = [];

assembly_contents = cell(size(Nclusters));
for k=1:Nclusters
    assembly_contents(k) = {find(PI(:,k)>=0.05)};
end
end