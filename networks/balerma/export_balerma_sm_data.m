function [diameters,rankings,ga] = export_balerma_sm_data(paper_root,result_dir)
%EXPORT_BALERMA_SM_DATA Export saved common-bound Balerma data for the SM.
% Reads the six saved full-network MAT results and frozen pipe ranking.
% Does not run GA, hydraulics, water quality, or failure scenarios.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
network_dir=fullfile(paper_root,'networks','balerma');
addpath(network_dir,'-begin');
cfg=network_config(network_dir);
if nargin<2 || isempty(result_dir)
    result_dir=fullfile(network_dir, ...
        'results_staci_uniform_0p1_64in_sourceentry_v4');
end
objectives=["cost","hydraulic_entropy", ...
    "branch_hop_weighted_entropy","chlorine_concentration", ...
    "chlorine_entropy","todini"];
labels={'Cost','FlowEntropy','BranchHopEntropy', ...
    'ChlorineConcentration','ChlorineEntropy','Todini'};
pipe_ids="P"+string(cfg.design_link_ids(:));
assert(numel(pipe_ids)==454,'Expected 454 Balerma physical pipes');
values=nan(454,6);
generations=zeros(6,1);
evaluations=nan(6,1);
seconds=zeros(6,1);
violations=zeros(6,1);
for k=1:6
    saved=load(fullfile(result_dir,objectives(k)+'.mat'),'result');
    r=saved.result;
    assert(strcmp(r.constraint_set_id,cfg.constraint_set_id) && ...
        r.minimum_diameter==cfg.minimum_diameter && ...
        r.maximum_diameter==cfg.maximum_diameter, ...
        'Incompatible Balerma saved constraints: %s',objectives(k));
    assert(isequal(string(r.design_link_ids(:)), ...
        string(cfg.design_link_ids(:))), ...
        'Saved Balerma pipe order differs from input: %s',objectives(k));
    values(:,k)=double(r.design_diameters(:));
    generations(k)=r.ga_last_generation;
    if isfield(r.output,'funccount'),evaluations(k)=r.output.funccount;end
    seconds(k)=r.elapsed_time_seconds;
    violations(k)=r.max_constraint_violation;
end
assert(all(isfinite(values(:))) && ...
    all(values(:)>=cfg.minimum_diameter-1e-8) && ...
    all(values(:)<=cfg.maximum_diameter+1e-8) && ...
    all(violations<=cfg.ga.constraint_tolerance), ...
    'A Balerma final design is outside the common feasible set');
diameters=table(pipe_ids,'VariableNames',{'PipeID'});
for k=1:6,diameters.([labels{k} '_mm'])=values(:,k);end
writetable(diameters,fullfile(result_dir, ...
    'optimal_pipe_diameters_six_mm.csv'));
for k=1:6
    diameters.([labels{k} '_in'])=values(:,k)/25.4;
end
inches=diameters(:,[{'PipeID'},strcat(labels,'_in')]);
writetable(inches,fullfile(result_dir, ...
    'optimal_pipe_diameters_six_in.csv'));
ga=table(objectives(:),generations,evaluations,seconds,violations, ...
    'VariableNames',{'Objective','Generations','Evaluations', ...
    'WallSeconds','MaxConstraintViolation'});
writetable(ga,fullfile(result_dir,'ga_stop_six_full.csv'));
ranking_file=fullfile(result_dir,'pipe_rankings.mat');
if isfile(ranking_file)
    loaded=load(ranking_file,'ranking');
    r=loaded.ranking;
    count=floor(0.2*numel(pipe_ids));
    assert(count==90 && size(r.ordered_link_ids,1)==454, ...
        'Balerma 20-percent pipe ranking has the wrong size');
    rankings=table((1:count)','VariableNames',{'Rank'});
    keys={'FlowRate','PressureSensitivity','NodalEntropy', ...
        'EntropySensitivity','Volume'};
    for k=1:5
        rankings.(keys{k})="P"+string(r.ordered_link_ids(1:count,k));
    end
    rankings.ReleasedPercent=100*rankings.Rank/454;
    writetable(rankings,fullfile(result_dir, ...
        'pipe_rankings_top90.csv'));
else
    rankings=table();
end
weighting=balerma_connected_branch_weights(cfg);
saved_branch=load(fullfile(result_dir, ...
    'branch_hop_weighted_entropy.mat'),'result');
assert(isfield(saved_branch.result,'branch_hop_weighting') && ...
    strcmp(saved_branch.result.branch_hop_weighting.version, ...
    weighting.version), ...
    'The saved Balerma branch-hop design uses another source convention');
node_weights=table(string(weighting.node_ids(:)), ...
    double(weighting.branch_hops(:)),double(weighting.weights(:)), ...
    'VariableNames',{'NodeID','Hop','Weight'});
writetable(node_weights,fullfile(result_dir, ...
    'branch_hop_source_weights.csv'));
end
