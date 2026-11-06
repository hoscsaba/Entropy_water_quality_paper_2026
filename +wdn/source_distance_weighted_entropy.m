function [value, split_entropy] = source_distance_weighted_entropy(staci,cfg,weights)
%SOURCE_DISTANCE_WEIGHTED_ENTROPY Replace throughput weights by fixed nodal weights.
% The canonical paper contribution is (T_i/Q_total)*H_i(split), where T_i is
% local throughput. Recover the unweighted Shannon split H_i, then use the
% frozen source-distance or branching-hop weight w_i instead of T_i/Q_total.
% Preserve the conventional source-share term when several sources feed
% the physical graph; it vanishes for single-source Anytown.

[~,details]=wdn.staci_flow_entropy(staci,cfg,[]);
weights=double(weights(:));
n=numel(details.node_entropy);
assert(numel(weights)==n,'Distance weight and node count differ');
split_entropy=zeros(n,1);
active=details.throughflow>eps;
split_entropy(active)=double(details.node_entropy(active)) .* ...
    details.total_supply ./ double(details.throughflow(active));
value=details.source_entropy+sum(weights.*split_entropy);
end
