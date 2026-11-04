function run_anytown_optimizations
%RUN_ANYTOWN_OPTIMIZATIONS Run the five Anytown single-objective optimizations.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'anytown');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

if ~exist(cfg.results_dir, 'dir')
    mkdir(cfg.results_dir);
end

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
previous_dir = pwd;
cd(cfg.runtime_dir);
directory_cleanup = onCleanup(@() cd(previous_dir));
original_design = model.original_full_diameters(model.design_link_indices);
baseline.network_id = cfg.id;
baseline.full_link_ids = cellstr(model.link_ids);
baseline.full_diameters = model.original_full_diameters;
baseline.metrics = wdn.evaluate_design(d, original_design, cfg, model);
save(fullfile(cfg.results_dir, 'baseline.mat'), 'baseline', 'cfg');
clear directory_cleanup cleanup d model;

for k = 1:numel(cfg.objectives)
    objective_name = cfg.objectives{k};
    fprintf('\n=== %s / %s ===\n', cfg.id, objective_name);
    result = wdn.optimize_single_objective(cfg, objective_name);
    save(fullfile(cfg.results_dir, [objective_name '.mat']), 'result', 'cfg');
end

wdn.synchronize_objective_archive(cfg);
wdn.write_cross_evaluation(cfg);
end
