function make_anytown_figures
%MAKE_ANYTOWN_FIGURES Create pressure- and chlorine-coloured 2-by-3 matrices.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root);
network_dir = fullfile(root, 'networks', 'anytown');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

if ~exist(cfg.figures_dir, 'dir')
    mkdir(cfg.figures_dir);
end
make_anytown_schematic;
wdn.plot_objective_matrix(cfg, ...
    fullfile(cfg.figures_dir, 'figure4.png'), 'pressure');
wdn.plot_objective_matrix(cfg, ...
    fullfile(cfg.figures_dir, 'figure5.png'), 'chlorine');

generated_dir = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(generated_dir), mkdir(generated_dir); end
copyfile(fullfile(cfg.figures_dir, 'figure4.png'), ...
    fullfile(generated_dir, 'figure4.png'), 'f');
copyfile(fullfile(cfg.figures_dir, 'figure5.png'), ...
    fullfile(generated_dir, 'figure5.png'), 'f');
end
