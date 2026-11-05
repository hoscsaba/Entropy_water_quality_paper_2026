function result = continue_balerma_capped_objective( ...
        staci_root, mex_dir, objective, extra_wall_seconds)
%CONTINUE_BALERMA_CAPPED_OBJECTIVE Resume a 2000-generation STACI GA.
% Preserve both runs and promote the best feasible continuation. The first
% run is never repeated; a completed continuation MAT is reused.
objective = string(objective);
assert(ismember(objective, ["hydraulic_entropy", ...
    "chlorine_entropy", "todini"]), 'Unexpected Balerma continuation');
root = fileparts(mfilename('fullpath'));
network_dir = fullfile(root, 'networks', 'balerma');
addpath(root, network_dir, fullfile(staci_root,'matlab'), mex_dir);
result_dir = fullfile(network_dir, 'results_staci');
primary_file = fullfile(result_dir, objective + ".mat");
stage1_file = fullfile(result_dir, objective + "_stage1.mat");
continuation_file = fullfile(result_dir, objective + "_continuation.mat");
if isfile(stage1_file)
    saved = load(stage1_file, 'result');
else
    saved = load(primary_file, 'result');
    result = saved.result; %#ok<NASGU>
    save(stage1_file, 'result', '-v7');
end
first = saved.result;
assert(first.ga_last_generation >= 2000, ...
    '%s first-stage run did not reach 2000 generations', objective);
if isfile(continuation_file)
    saved = load(continuation_file, 'result');
    result = saved.result;
else
    cfg = network_config(network_dir);
    cfg.ga.max_generations = 10000;
    cfg.ga.max_stall_generations = 150;
    cfg.ga.maximum_wall_seconds = extra_wall_seconds;
    cfg.ga.display = 'final';
    input_file = fullfile(network_dir, 'input', ...
        'network_staci_fixed_load.inp');
    result = wdn.optimize_staci_single_objective(cfg, ...
        char(objective), input_file, continuation_file);
end
assert(result.optimizer_value <= first.optimizer_value + 1e-8, ...
    'The continuation lost the saved feasible incumbent');
result.prior_run = struct( ...
    'generations',first.ga_last_generation, ...
    'evaluations',first.output.funccount, ...
    'wall_seconds',first.elapsed_time_seconds, ...
    'generation_cap',first.ga_max_generations, ...
    'stop_message',string(first.output.message));
result.continuation_from = objective + "_stage1.mat";
save(primary_file, 'result', '-v7');
fprintf('Balerma %s after continuation: %.9g, total %.0f s\n', ...
    objective, -result.optimizer_value, ...
    first.elapsed_time_seconds + result.elapsed_time_seconds);
end
