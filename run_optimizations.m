function run_optimizations
%RUN_OPTIMIZATIONS Optimise all five Figure 3 objectives for the first network.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'tanyimboh_templeman');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

if ~exist(cfg.results_dir, 'dir')
    mkdir(cfg.results_dir);
end

for k = 1:numel(cfg.objectives)
    objective_name = cfg.objectives{k};
    fprintf('\n=== %s / %s ===\n', cfg.id, objective_name);
    result = wdn.optimize_single_objective(cfg, objective_name);
    output_file = fullfile(cfg.results_dir, [objective_name '.mat']);
    save(output_file, 'result', 'cfg');
end

wdn.synchronize_objective_archive(cfg);
wdn.write_cross_evaluation(cfg);
end
