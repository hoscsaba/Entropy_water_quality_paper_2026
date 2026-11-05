function summary = finalize_staci_single_objectives(staci_root, mex_dir, networks)
%FINALIZE_STACI_SINGLE_OBJECTIVES Build STACI baselines and cross-evaluation.
root = fileparts(mfilename('fullpath'));
addpath(root, fullfile(staci_root, 'matlab'), mex_dir);
if nargin < 3 || isempty(networks)
    networks = ["tanyimboh_templeman","anytown","balerma"];
else
    networks = string(networks);
end
summary_rows = cell(5 * numel(networks), 14);
row = 0;
for network = networks
    network_dir = char(fullfile(root, 'networks', network));
    addpath(network_dir);
    cfg = network_config(network_dir);
    input_file = fullfile(network_dir, 'input', 'network_staci_fixed_load.inp');
    st = StaciModel(input_file);
    st_cleanup = onCleanup(@() st.release());
    design_ids = string(cfg.design_link_ids(:));
    if network == "anytown", diameter_scale = 0.0254;
    else, diameter_scale = 0.001;
    end
    [link_order, original_full] = wdn.staci_input_link_template( ...
        input_file, st, diameter_scale);
    original_full = original_full(:)';
    original_design = double(st.getLinkProperty(design_ids, 'diameter_m')) ...
        / diameter_scale;
    [found, positions] = ismember(design_ids, link_order);
    assert(all(found), 'Original link order mismatch');
    original_full(positions) = original_design;
    [metrics, violation] = wdn.evaluate_staci_design( ...
        st, cfg, original_design, link_order, original_full);
    baseline.network_id = cfg.id;
    baseline.model = 'staci_steady_first_order';
    baseline.full_link_ids = cellstr(link_order);
    baseline.full_diameters = original_full;
    baseline.design_diameters = original_design;
    baseline.metrics = metrics;
    baseline.max_constraint_violation = violation;
    output_dir = fullfile(network_dir, 'results_staci');
    save(fullfile(output_dir, 'baseline.mat'), 'baseline', '-v7');
    cfg.results_dir = output_dir;
    for objective = string(cfg.objectives)
        saved = load(fullfile(output_dir, objective + ".mat"), 'result');
        result = saved.result;
        % Keep the archived MAT portable after staging or cloning the repo.
        portable_input = fullfile('networks', cfg.id, 'input', ...
            'network_staci_fixed_load.inp');
        if ~isfield(result, 'input_file') || ...
                ~strcmp(char(result.input_file), portable_input)
            result.input_file = portable_input;
            save(fullfile(output_dir, objective + ".mat"), 'result', '-v7');
        end
        row = row + 1;
        m = result.metrics;
        generations = result.ga_last_generation;
        evaluations = result.output.funccount;
        wall_seconds = result.elapsed_time_seconds;
        generation_cap = result.ga_max_generations;
        if isfield(result, 'prior_run')
            generations = generations + result.prior_run.generations;
            evaluations = evaluations + result.prior_run.evaluations;
            wall_seconds = wall_seconds + result.prior_run.wall_seconds;
            generation_cap = generation_cap + result.prior_run.generation_cap;
        end
        stop_message = strip(regexprep(string(result.output.message), '\s+', ' '));
        if contains(lower(stop_message), 'output function') && ...
                isfield(result, 'maximum_wall_seconds') && ...
                result.elapsed_time_seconds >= result.maximum_wall_seconds - 60
            stop_message = stop_message + " (wall-clock limit)";
        end
        summary_rows(row,:) = {network, objective, m.cost, ...
            m.hydraulic_entropy, m.chlorine_concentration, ...
            m.chlorine_entropy, m.todini, generations, ...
            result.exitflag, wall_seconds, ...
            result.max_constraint_violation, ...
            evaluations, generation_cap, stop_message};
    end
    wdn.write_cross_evaluation(cfg);
    clear st_cleanup st;
    rmpath(network_dir);
end
summary = cell2table(summary_rows, 'VariableNames', ...
    {'network','objective','cost','hydraulic_entropy', ...
     'chlorine_concentration','chlorine_entropy','todini', ...
     'ga_generations','ga_exitflag','ga_wall_seconds', ...
     'max_constraint_violation','ga_function_evaluations', ...
     'ga_generation_cap','ga_stop_message'});
writetable(summary, fullfile(root, 'supplementary', 'results', ...
    'staci_single_objective_summary.csv'));
end
