function regenerate_anytown_ranking_figure
%REGENERATE_ANYTOWN_RANKING_FIGURE Replot Figure 9 without optimization.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root);
results_file = fullfile(root, 'networks', 'anytown', 'results', ...
    'ranking_dual_study.mat');
saved = load(results_file, 'cost_study', 'entropy_study', 'normalizers', 'cfg');
files = wdn.plot_ranking_objective_matrix(saved.cfg, saved.cost_study, ...
    saved.entropy_study, saved.normalizers);

draft_figures = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(draft_figures), mkdir(draft_figures); end
for k = 1:numel(files)
    [~, name, extension] = fileparts(files{k});
    copyfile(files{k}, fullfile(draft_figures, [name extension]), 'f');
end
end
