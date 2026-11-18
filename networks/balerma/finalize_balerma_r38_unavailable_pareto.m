function files=finalize_balerma_r38_unavailable_pareto( ...
        paper_root,staci_root,mex_dir)
%FINALIZE_BALERMA_R38_UNAVAILABLE_PARETO Replay and plot saved Pareto points.
% The nominal cost--branch-hop archive must already exist. Each selected
% point receives 448 PDA pipe failures with R38 and P5/P338 unavailable.
% Cached point replays are checked against exact diameter vectors.
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
addpath(paper_root,network_dir,fullfile(paper_root,'manuscript','figures'), ...
    fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
study_dir=fullfile(cfg.results_dir,'pareto_r38_unavailable_study');
assert(isfile(fullfile(study_dir,'pareto_cost_branch_hop_top90.mat')) && ...
    isfile(fullfile(study_dir,'pareto_selected20_indices.csv')), ...
    'Complete the nominal Pareto search and point selection first');
summary=run_balerma_r38_pareto_replay( ...
    paper_root,staci_root,mex_dir,[],"r38_unavailable");
assert(height(summary)==20 && ...
    all(summary.FailureCases==448) && ...
    all(summary.NonconvergentScenarios==0), ...
    'R38-unavailable Pareto replay is incomplete');
figure_dir=fullfile(network_dir,'figures_staci_r38_anchor_v1');
files=make_balerma_common_pareto(paper_root,study_dir,figure_dir, ...
    'r38_anchor_r38_unavailable');
end
