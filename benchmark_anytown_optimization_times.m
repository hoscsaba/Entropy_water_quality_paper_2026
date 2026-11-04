function timing = benchmark_anytown_optimization_times
%BENCHMARK_ANYTOWN_OPTIMIZATION_TIMES Time the five Anytown GA searches.
%   The validated production MAT files are used only as feasible seeds and
%   are not overwritten. Both process CPU time and elapsed wall-clock time
%   are saved; normalized values use the shortest CPU time as unity.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'anytown');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

n = numel(cfg.objectives);
objective = strings(n, 1);
cpu_time_seconds = zeros(n, 1);
elapsed_time_seconds = zeros(n, 1);
function_evaluations = zeros(n, 1);
generations = zeros(n, 1);

for k = 1:n
    objective(k) = string(cfg.objectives{k});
    fprintf('\n=== timing %s / %s ===\n', cfg.id, objective(k));
    timed_result = wdn.optimize_single_objective(cfg, objective(k));
    cpu_time_seconds(k) = timed_result.cpu_time_seconds;
    elapsed_time_seconds(k) = timed_result.elapsed_time_seconds;
    function_evaluations(k) = timed_result.output.funccount;
    generations(k) = timed_result.output.generations;
end

normalized_cpu_time = cpu_time_seconds / min(cpu_time_seconds);
timing = table(objective, cpu_time_seconds, normalized_cpu_time, ...
    elapsed_time_seconds, function_evaluations, generations);
writetable(timing, fullfile(cfg.results_dir, ...
    'optimization_timing.csv'));
save(fullfile(cfg.results_dir, 'optimization_timing.mat'), ...
    'timing', 'cfg');
disp(timing);
end
