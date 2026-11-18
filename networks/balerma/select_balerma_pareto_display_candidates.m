function selected=select_balerma_pareto_display_candidates(result_dir,count)
%SELECT_BALERMA_PARETO_DISPLAY_CANDIDATES Choose before PDA replay.
% Select existing nondominated 90-pipe designs approximately uniformly by
% normalized-objective arclength. This operation uses saved nominal metrics
% only, so the failure-service indicators cannot influence point selection.
if nargin<2 || isempty(count),count=20;end
assert(isscalar(count) && count>=2 && count==floor(count));
saved=load(fullfile(result_dir,'pareto_cost_branch_hop_top90.mat'),'result');
r=saved.result;
expected_version='reservoir_zero_hop_root_v4';
if contains(string(result_dir),'r38_anchor')
    expected_version='balerma_r38_anchor_four_potential_supply_roots_v1';
end
assert(isfield(r,'branch_hop_weighting_version') && ...
    strcmp(r.branch_hop_weighting_version,expected_version), ...
    'The Balerma candidate archive uses obsolete source weights');
n=size(r.designs,1);
[~,order]=sortrows([double(r.cost(:)),-double(r.branch_hop_entropy(:))],[1 2]);
cost=double(r.cost(order))/1e6;
entropy=double(r.branch_hop_entropy(order));
keep=false(n,1);best=-inf;
for k=1:n
    if entropy(k)>best+1e-9
        keep(k)=true;best=entropy(k);
    end
end
indices=order(keep);cost=cost(keep);entropy=entropy(keep);
assert(numel(indices)>=2,'At least two nondominated designs are required');
target=min(count,numel(indices));
if target==numel(indices)
    chosen=(1:target)';
else
    x=(cost-min(cost))/max(max(cost)-min(cost),eps);
    y=(entropy-min(entropy))/max(max(entropy)-min(entropy),eps);
    distance=[0;cumsum(hypot(diff(x),diff(y)))];
    if distance(end)<=eps
        distance=linspace(0,1,numel(indices))';
    end
    chosen=[1;numel(indices)];
    while numel(chosen)<target
        gap=min(abs(distance-distance(chosen)'),[],2);
        gap(chosen)=-inf;
        [~,next]=max(gap);
        chosen(end+1,1)=next; %#ok<AGROW>
    end
    chosen=sort(chosen);
end
selected=table(indices(chosen),cost(chosen),entropy(chosen), ...
    'VariableNames',{'ArchiveIndex','CostMillion','BranchHopEntropy'});
writetable(selected,fullfile(result_dir,'pareto_selected20_indices.csv'));
fprintf('Balerma: selected %d of %d nondominated candidates from %d designs\n', ...
    height(selected),numel(indices),n);
end
