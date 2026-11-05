function finalize_balerma_cross_elites(staci_root, mex_dir)
%FINALIZE_BALERMA_CROSS_ELITES Recheck cross-objective STACI warm starts.
% Chlorine-entropy search found a better H-entropy seed. The chlorine-
% concentration search found a marginally cheaper feasible seed. Continue
% those objectives once, preserving each prior run and the exact GA record.
root = fileparts(mfilename('fullpath'));
network_dir = fullfile(root, 'networks', 'balerma');
result_dir = fullfile(network_dir, 'results_staci');
addpath(root, network_dir, fullfile(staci_root,'matlab'), mex_dir);
cfg = network_config(network_dir);
cfg.ga.max_generations = 10000;
cfg.ga.max_stall_generations = 150;
cfg.ga.display = 'final';
input_file = fullfile(network_dir,'input','network_staci_fixed_load.inp');

promote('hydraulic_entropy','hydraulic_entropy_stage3.mat',150);
promote('cost','cost_continuation.mat',300);

    function promote(objective, continuation_name, wall_seconds)
        primary_file = fullfile(result_dir, objective + ".mat");
        stage_file = fullfile(result_dir, objective + "_pre_elite.mat");
        continuation_file = fullfile(result_dir, continuation_name);
        if isfile(stage_file)
            old = load(stage_file,'result');
        else
            old = load(primary_file,'result');
            result = old.result; %#ok<NASGU>
            save(stage_file,'result','-v7');
        end
        if isfile(continuation_file)
            saved = load(continuation_file,'result');
            result = saved.result;
        else
            cfg.ga.maximum_wall_seconds = wall_seconds;
            result = wdn.optimize_staci_single_objective( ...
                cfg,objective,input_file,continuation_file);
        end
        assert(result.optimizer_value <= old.result.optimizer_value + 1e-8, ...
            '%s continuation lost its feasible elite seed',objective);
        generations = old.result.ga_last_generation;
        evaluations = old.result.output.funccount;
        elapsed = old.result.elapsed_time_seconds;
        cap = old.result.ga_max_generations;
        if isfield(old.result,'prior_run')
            generations = generations + old.result.prior_run.generations;
            evaluations = evaluations + old.result.prior_run.evaluations;
            elapsed = elapsed + old.result.prior_run.wall_seconds;
            cap = cap + old.result.prior_run.generation_cap;
        end
        result.prior_run = struct( ...
            'generations',generations,'evaluations',evaluations, ...
            'wall_seconds',elapsed,'generation_cap',cap, ...
            'stop_message',string(old.result.output.message));
        result.continuation_from = objective + "_pre_elite.mat";
        save(primary_file,'result','-v7');
        fprintf('Balerma %s cross-elite continuation: %.9g, total %.0f s\n', ...
            objective,result.optimizer_value, ...
            elapsed + result.elapsed_time_seconds);
    end
end
