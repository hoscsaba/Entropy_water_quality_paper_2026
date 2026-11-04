function run_balerma_optimizations(objectives_to_run)
%RUN_BALERMA_OPTIMIZATIONS Run reproducible Balerma GA searches.
%   RUN_BALERMA_OPTIMIZATIONS runs all five objectives.
%   RUN_BALERMA_OPTIMIZATIONS("hydraulic_entropy") reruns only the named
%   objective and then rebuilds the cross-evaluation from all saved designs.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'balerma');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

if nargin == 0 || isempty(objectives_to_run)
    objectives_to_run = string(cfg.objectives);
else
    objectives_to_run = string(objectives_to_run);
end
unknown = setdiff(objectives_to_run, string(cfg.objectives));
if ~isempty(unknown)
    error('balerma:UnknownObjective', 'Unknown objective(s): %s', ...
        strjoin(unknown, ', '));
end

if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end
if ~exist(cfg.runtime_dir, 'dir'), mkdir(cfg.runtime_dir); end

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

for k = 1:numel(objectives_to_run)
    objective_name = objectives_to_run(k);
    fprintf('\n=== %s / %s ===\n', cfg.id, objective_name);
    result = wdn.optimize_single_objective(cfg, objective_name);
    save(fullfile(cfg.results_dir, objective_name + ".mat"), 'result', 'cfg');
end

selections = wdn.synchronize_objective_archive(cfg);
disp(selections);
wdn.write_cross_evaluation(cfg);
end
