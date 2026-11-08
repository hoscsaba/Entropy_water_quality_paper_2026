function make_figure3
%MAKE_FIGURE3 Six optimized TT designs for Supplementary Figure S4.
% The original network is retained as an INP/baseline, but has no panel.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root);
network_dir = fullfile(root, 'networks', 'tanyimboh_templeman');
addpath(network_dir);
cfg = network_config(network_dir);
cfg.results_dir = fullfile(network_dir,'results_staci');
cfg.figures_dir = fullfile(network_dir,'figures_staci');
cfg.plot.matrix_objectives = {'cost','hydraulic_entropy', ...
    'branch_hop_weighted_entropy','chlorine_concentration', ...
    'chlorine_entropy','todini'};
cfg.plot.matrix_titles = {'Cost','Hydraulic entropy','Branch-hop entropy', ...
    'Chlorine concentration','Chlorine entropy','Todini index'};
% Preserve the original six-panel pressure scale after replacing its panel.
saved = load(fullfile(cfg.results_dir,'baseline.mat'),'baseline');
original_pressure = saved.baseline.metrics.pressures;
cfg.plot.pressure_limits = [cfg.minimum_pressure, ...
    max(original_pressure(:))];
wdn.setup_toolkit(cfg);

if ~exist(cfg.figures_dir, 'dir')
    mkdir(cfg.figures_dir);
end

output_file = fullfile(cfg.figures_dir, 'figure3.png');
wdn.plot_objective_matrix(cfg, output_file);
generated_dir = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(generated_dir), mkdir(generated_dir); end
copyfile(output_file, fullfile(generated_dir, 'figure3.png'), 'f');
copyfile(fullfile(cfg.figures_dir,'figure3.svg'), ...
    fullfile(generated_dir,'figure3.svg'),'f');
fprintf('Figure written to %s\n', output_file);
end
