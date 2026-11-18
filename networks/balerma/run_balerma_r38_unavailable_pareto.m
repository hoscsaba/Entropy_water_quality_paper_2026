function study_dir=run_balerma_r38_unavailable_pareto( ...
        paper_root,staci_root,mex_dir)
%RUN_BALERMA_R38_UNAVAILABLE_PARETO Repeat the nominal cost--branch-hop GA.
% The optimized nominal model still has the zero-flow R38 pressure anchor.
% Source and pipe failures are evaluated only after optimization. A
% separate study directory preserves the existing all-four-reservoir
% Pareto archive and its replay/checkpoints.
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
cfg=network_config_r38_anchor(network_dir);
source_dir=cfg.results_dir;
study_dir=fullfile(source_dir,'pareto_r38_unavailable_study');
if ~isfolder(study_dir),mkdir(study_dir);end
source_rank=fullfile(source_dir,'pipe_rankings.mat');
target_rank=fullfile(study_dir,'pipe_rankings.mat');
if ~isfile(target_rank),copyfile(source_rank,target_rank);end
for objective=["cost","branch_hop_weighted_entropy"]
    source=fullfile(source_dir,'ranking_cache',char(objective), ...
        'volume','k_090.mat');
    target=fullfile(study_dir,'ranking_cache',char(objective), ...
        'volume','k_090.mat');
    if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
    if ~isfile(target),copyfile(source,target);end
end
result_file=fullfile(study_dir,'pareto_cost_branch_hop_top90.mat');
if isfile(result_file)
    old=load(result_file,'result');
    assert(strcmp(old.result.constraint_set_id,cfg.constraint_set_id) && ...
        strcmp(old.result.branch_hop_weighting_version, ...
        cfg.branch_hop_weighting.version) && ...
        old.result.optimized_pipe_count==90, ...
        'Incompatible R38-unavailable Pareto checkpoint');
    fprintf('Verified existing nominal Pareto checkpoint: %s\n',result_file);
else
    run_balerma_common_pareto(paper_root,staci_root,mex_dir,study_dir);
end
select_balerma_pareto_display_candidates(study_dir,20);
end
