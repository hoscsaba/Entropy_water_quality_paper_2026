function regenerate_anytown_ranking_figure
%REGENERATE_ANYTOWN_RANKING_FIGURE Replot Figure 9 from saved STACI studies.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
network_dir = fullfile(root, 'networks', 'anytown');
addpath(root, network_dir);
cfg = network_config(network_dir);
cfg.results_dir = fullfile(network_dir, 'results_staci');
cfg.figures_dir = fullfile(network_dir, 'figures_staci');
cost = load(fullfile(cfg.results_dir, 'ranking_cost_study.mat'), 'cost_study');
entropy = load(fullfile(cfg.results_dir, 'ranking_entropy_study.mat'), ...
    'entropy_study');
files = wdn.plot_ranking_objective_matrix(cfg, cost.cost_study, ...
    entropy.entropy_study, struct());

draft_figures = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(draft_figures), mkdir(draft_figures); end
for k = 1:numel(files)
    [~, name, extension] = fileparts(files{k});
    copyfile(files{k}, fullfile(draft_figures, [name extension]), 'f');
end
end
