function result = continue_balerma_hydraulic_entropy(staci_root, mex_dir)
%CONTINUE_BALERMA_HYDRAULIC_ENTROPY Continue the 2000-generation STACI run.
% The first run reached its generation cap. This second search starts from
% that incumbent and is limited to another 20 minutes, keeping the total
% hydraulic-entropy search close to the two-hour engineering budget.
root = fileparts(mfilename('fullpath'));
network_dir = fullfile(root, 'networks', 'balerma');
addpath(root, network_dir, fullfile(staci_root,'matlab'), mex_dir);
result_dir = fullfile(network_dir, 'results_staci');
primary_file = fullfile(result_dir, 'hydraulic_entropy.mat');
stage1_file = fullfile(result_dir, 'hydraulic_entropy_stage1.mat');
continuation_file = fullfile(result_dir, 'hydraulic_entropy_continuation.mat');
if isfile(stage1_file)
    saved = load(stage1_file, 'result');
else
    saved = load(primary_file, 'result');
    result = saved.result; %#ok<NASGU>
    save(stage1_file, 'result', '-v7');
end
first = saved.result;
assert(first.ga_last_generation >= 2000, ...
    'The original Balerma hydraulic-entropy run did not reach its ceiling');
if isfile(continuation_file)
    saved = load(continuation_file, 'result');
    result = saved.result;
else
    cfg = network_config(network_dir);
    cfg.ga.max_generations = 10000;
    cfg.ga.max_stall_generations = 150;
    cfg.ga.maximum_wall_seconds = 1200;
    cfg.ga.display = 'final';
    input_file = fullfile(network_dir, 'input', ...
        'network_staci_fixed_load.inp');
    result = wdn.optimize_staci_single_objective(cfg, ...
        'hydraulic_entropy', input_file, continuation_file);
end
assert(result.optimizer_value <= first.optimizer_value + 1e-8, ...
    'The continuation lost the saved feasible incumbent');
result.prior_run = struct( ...
    'generations',first.ga_last_generation, ...
    'evaluations',first.output.funccount, ...
    'wall_seconds',first.elapsed_time_seconds, ...
    'generation_cap',first.ga_max_generations, ...
    'stop_message',string(first.output.message));
result.continuation_from = 'hydraulic_entropy_stage1.mat';
save(primary_file, 'result', '-v7');
fprintf('Balerma H entropy after continuation: %.9g, total %.0f s\n', ...
    result.metrics.hydraulic_entropy, ...
    first.elapsed_time_seconds + result.elapsed_time_seconds);
end
