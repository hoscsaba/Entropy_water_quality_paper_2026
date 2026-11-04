function run_anytown_stress_test
%RUN_ANYTOWN_STRESS_TEST Evaluate every single-pipe failure for five designs.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'anytown');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

if ~exist(cfg.results_dir, 'dir')
    mkdir(cfg.results_dir);
end

result_files = string(cfg.objectives) + ".mat";
topology_names = ["Cost", "Hydraulic entropy", "Chlorine concentration", ...
    "Chlorine entropy", "Todini"];
n_topologies = numel(result_files);
summaries = cell(n_topologies, 1);
scenario_tables = cell(n_topologies, 1);

for k = 1:n_topologies
    result_path = fullfile(cfg.results_dir, result_files(k));
    if ~isfile(result_path)
        error('wdn:StressResultMissing', 'Optimization result is missing: %s', result_path);
    end
    loaded = load(result_path, 'result');
    fprintf('\n=== Anytown stress test / %s ===\n', topology_names(k));
    [summaries{k}, scenario_tables{k}] = wdn.pipe_failure_stress_test( ...
        cfg, loaded.result.design_diameters, topology_names(k));
end

summary_struct = vertcat(summaries{:});
summary_table = struct2table(summary_struct);
scenario_table = vertcat(scenario_tables{:});
save(fullfile(cfg.results_dir, 'stress_test.mat'), ...
    'summary_struct', 'summary_table', 'scenario_table', 'cfg');
writetable(summary_table, fullfile(cfg.results_dir, 'stress_test.csv'));
writetable(scenario_table, fullfile(cfg.results_dir, 'stress_test_scenarios.csv'));

disp(summary_table(:, {'topology','pressure_violation_fraction', ...
    'chlorine_violation_fraction','mean_chlorine_mg_L', ...
    'chlorine_cv_fraction','nonconvergent_scenario_count'}));
end
