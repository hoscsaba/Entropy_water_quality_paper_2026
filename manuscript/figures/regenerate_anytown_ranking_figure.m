function regenerate_anytown_ranking_figure
%REGENERATE_ANYTOWN_RANKING_FIGURE Replot Figure 9 from saved STACI studies.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
network_dir = fullfile(root, 'networks', 'anytown');
addpath(root, network_dir);
cfg = network_config(network_dir);
cfg.results_dir = fullfile(network_dir, 'results_staci');
cfg.figures_dir = fullfile(network_dir, 'figures_staci');
if isfile(fullfile(cfg.results_dir,'ranking_branch_hop_study.mat'))
    cost=load(fullfile(cfg.results_dir, ...
        'ranking_cost_branch_hop_study.mat'),'cost_branch_study');
    entropy=load(fullfile(cfg.results_dir, ...
        'ranking_branch_hop_study.mat'),'branch_study');
    cost_study=cost.cost_branch_study;
    entropy_study=entropy.branch_study;
else
    cost=load(fullfile(cfg.results_dir, ...
        'ranking_cost_study.mat'),'cost_study');
    entropy=load(fullfile(cfg.results_dir, ...
        'ranking_entropy_study.mat'),'entropy_study');
    cost_study=cost.cost_study;
    entropy_study=entropy.entropy_study;
end
files = wdn.plot_ranking_objective_matrix(cfg, cost_study, ...
    entropy_study, struct());

draft_figures = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(draft_figures), mkdir(draft_figures); end
for k = 1:numel(files)
    [~, name, extension] = fileparts(files{k});
    copyfile(files{k}, fullfile(draft_figures, [name extension]), 'f');
end
end
