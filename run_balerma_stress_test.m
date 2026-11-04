function run_balerma_stress_test
%RUN_BALERMA_STRESS_TEST Evaluate all 454 single-pipe failures for five designs.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'balerma');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

result_files = string(cfg.objectives) + ".mat";
topology_names = ["Cost", "Hydraulic entropy", "Chlorine concentration", ...
    "Chlorine entropy", "Todini"];
summaries = cell(numel(result_files), 1);
scenario_tables = cell(numel(result_files), 1);
for k = 1:numel(result_files)
    loaded = load(fullfile(cfg.results_dir, result_files(k)), 'result');
    fprintf('\n=== Balerma stress test / %s ===\n', topology_names(k));
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
