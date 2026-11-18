function results=evaluate_balerma_pareto_r43_p24( ...
        paper_root,staci_root,mex_dir)
%EVALUATE_BALERMA_PARETO_R43_P24 Replay one interpretable compound failure.
% For the same 20 selected 90-pipe Pareto vectors, isolate R43 by closing
% its two physical connectors P194 and P223. Measure demand served with
% R43 alone unavailable and then with nonconnector pipe P24 also closed.
% No optimization or all-pipe failure replay occurs in this routine.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2 || isempty(staci_root)
    staci_root='/Users/hoscsaba/Documents/GitHub/staci';
end
if nargin<3 || isempty(mex_dir)
    mex_dir=fullfile(staci_root,'build-matlab','Matlab');
end
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config(network_dir);
result_dir=fullfile(network_dir, ...
    'results_staci_uniform_0p1_64in_sourceentry_v4');
out_dir=fullfile(result_dir,'pareto_r43_p24');
if ~isfolder(out_dir),mkdir(out_dir);end
cfg.results_dir=char(out_dir);
cfg.stress.allow_pda_tolerance_fallback=true;
cfg.stress.disabled_link_ids=cfg.stress.r43_connector_link_ids;
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
pda_file=fullfile(out_dir,'runtime','network_pda_fixed_load.inp');
wdn.write_staci_pda_input(cfg,input_file,pda_file);
base=StaciModel(input_file);
node_ids=string(cfg.stress.node_ids(:));
requested=max(double(base.getNodeProperty( ...
    node_ids,'demand_m3s')),0);
requested=requested(:);
base.release();
denominator=sum(requested);
archive=load(fullfile(result_dir, ...
    'pareto_cost_branch_hop_top90.mat'),'result');
selected=readtable(fullfile(result_dir, ...
    'pareto_selected20_indices.csv'));
ids=double(selected.ArchiveIndex(:));
assert(numel(ids)==20 && numel(unique(ids))==20);
rows=cell(numel(ids),1);
for k=1:numel(ids)
    id=ids(k);
    x=double(archive.result.designs(id,:));
    [delivered,~,chlorine,fallback]= ...
        wdn.staci_connected_outage_outputs( ...
        cfg,x,pda_file,"24",node_ids,'pda');
    assert(~fallback);
    delivered=min(max(delivered(:),0),requested);
    water=100*sum(delivered)/denominator;
    compliant=100*sum(delivered.*( ...
        chlorine(:)>=cfg.stress.minimum_chlorine))/denominator;
    [baseline_delivered,~,~,baseline_fallback]= ...
        wdn.staci_connected_outage_outputs( ...
        cfg,x,pda_file,"194",node_ids,'pda');
    assert(~baseline_fallback);
    baseline_delivered=min(max( ...
        baseline_delivered(:),0),requested);
    baseline=100*sum(baseline_delivered)/denominator;
    rows{k}=table(id,archive.result.cost(id)/1e6, ...
        archive.result.branch_hop_entropy(id), ...
        water,compliant,baseline,baseline-water, ...
        'VariableNames',{'ArchiveIndex','CostMillion', ...
        'BranchHopEntropy','WaterServicePct', ...
        'ChlorineCompliantServicePct','R43OnlyServicePct', ...
        'AdditionalP24LossPp'});
end
results=sortrows(vertcat(rows{:}),'CostMillion');
writetable(results,fullfile(out_dir,'r43_p24_selected20.csv'));
fprintf('R43 + P24, 20 Pareto designs: water %.3f--%.3f%%; Cl %.3f--%.3f%%\n', ...
    min(results.WaterServicePct),max(results.WaterServicePct), ...
    min(results.ChlorineCompliantServicePct), ...
    max(results.ChlorineCompliantServicePct));
end
