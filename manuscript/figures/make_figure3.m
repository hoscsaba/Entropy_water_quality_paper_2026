function make_figure3
%MAKE_FIGURE3 Create the 2-by-3 topology matrix requested for manuscript Figure 3.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root);
network_dir = fullfile(root, 'networks', 'tanyimboh_templeman');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

if ~exist(cfg.figures_dir, 'dir')
    mkdir(cfg.figures_dir);
end

output_file = fullfile(cfg.figures_dir, 'figure3.png');
wdn.plot_objective_matrix(cfg, output_file);
generated_dir = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(generated_dir), mkdir(generated_dir); end
copyfile(output_file, fullfile(generated_dir, 'figure3.png'), 'f');
fprintf('Figure written to %s\n', output_file);
end
