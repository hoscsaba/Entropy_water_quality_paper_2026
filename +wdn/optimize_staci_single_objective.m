function result = optimize_staci_single_objective(cfg, objective_name, input_file, output_file)
%OPTIMIZE_STACI_SINGLE_OBJECTIVE In-memory STACI GA for paper objectives.
% Chlorine objectives constrain concentration at material-demand consumers.
% No candidate evaluation writes an INP, RPT, BIN or other sidecar file.
% For chlorine-directed searches, 0.2 mg/L is required only at junctions
% above the demand of a 10 mm pipe carrying water at 1 cm/s. The other
% searches report chlorine as a metric without imposing this floor.

assert(ismember(string(objective_name), string(cfg.objectives)));
chlorine_objective = ismember(string(objective_name), ...
    ["chlorine_concentration", "chlorine_entropy"]);
if strcmp(cfg.id, 'anytown')
    diameter_scale_m = 0.0254; % inches
    length_scale = 1 / 0.3048; % metres -> feet for paper cost
else
    diameter_scale_m = 0.001;  % millimetres
    length_scale = 1;
end
staci = StaciModel(input_file);
cleanup = onCleanup(@() staci.release());
[input_link_ids, input_diameters] = wdn.staci_input_link_template( ...
    input_file, staci, diameter_scale_m);
design_ids = string(cfg.design_link_ids(:));
nvars = numel(design_ids);
lb = cfg.minimum_diameter * ones(1, nvars);
ub = cfg.maximum_diameter * ones(1, nvars);
raw_diameters = staci.getLinkProperty(design_ids, 'diameter_m');
original_x = raw_diameters(:)' / diameter_scale_m;
x0 = min(max(original_x, lb), ub);
raw_lengths = staci.getLinkProperty(design_ids, 'length_m');
lengths = raw_lengths(:)' * length_scale;
initial_status = staci.solveHydraulics();
assert(initial_status.converged, 'Original STACI hydraulics failed');
node_state = staci.nodeResults();
node_ids = string(node_state.id(:));
nodal_split_weights = [];
weighting_field = '';
if strcmp(objective_name,'source_distance_weighted_entropy')
    weighting_field = 'source_distance_weighting';
elseif strcmp(objective_name,'branch_hop_weighted_entropy')
    weighting_field = 'branch_hop_weighting';
end
if ~isempty(weighting_field)
    assert(isfield(cfg,weighting_field), ...
        'Weighted-entropy objective requires fixed reference weights');
    weighting=cfg.(weighting_field);
    [found,weight_order]=ismember(node_ids,string(weighting.node_ids(:)));
    assert(all(found),'Weight node IDs differ from STACI nodes');
    nodal_split_weights=double(weighting.weights(weight_order));
end
threshold_m3s = pi / 4 * 0.010^2 * 0.01;
consumer_ids = node_ids(double(node_state.demand_m3s(:)) > threshold_m3s);
quality_ids = string(cfg.quality_node_ids(:));
pressure_ids = string(cfg.pressure_node_ids(:));
assert(all(ismember(quality_ids, node_ids)) && ...
    all(ismember(pressure_ids, node_ids)), 'Configured STACI nodes missing');
fprintf('%s: %d chlorine-constrained consumers (threshold %.8g m3/s)\n', ...
    cfg.id, numel(consumer_ids), threshold_m3s);

% Existing designs are documented warm starts; each is re-evaluated with
% STACI and the new chlorine constraint before it may become an incumbent.
rng(cfg.ga.random_seed, 'twister');
population = lb + rand(cfg.ga.population_size, nvars) .* (ub - lb);
population(1, :) = x0;
candidate_x = x0;
candidate_names = "original (bounded)";
% Final STACI results are read once before GA starts as feasible warm starts.
for name = string(cfg.objectives)
    if ismember(name,["source_distance_weighted_entropy", ...
            "branch_hop_weighted_entropy"])
        % Keep each distance experiment independent of its prior result.
        continue;
    end
    saved = fullfile(cfg.results_dir, name + ".mat");
    if ~isfile(saved), continue; end
    loaded = load(saved, 'result');
    if ~isfield(loaded, 'result') || ...
            numel(loaded.result.design_diameters) ~= nvars
        continue;
    end
    proposed = min(max(double(loaded.result.design_diameters(:)'), lb), ub);
    candidate_x(end + 1, :) = proposed; %#ok<AGROW>
    candidate_names(end + 1, 1) = "saved STACI " + name; %#ok<AGROW>
end
if isfield(cfg.ga, 'seed_designs') && ...
        isfield(cfg.ga.seed_designs, char(objective_name))
    seed = double(cfg.ga.seed_designs.(char(objective_name))(:)');
    assert(numel(seed) == nvars, 'Configured seed width mismatch');
    candidate_x(end + 1, :) = min(max(seed, lb), ub);
    candidate_names(end + 1, 1) = "configured seed";
end
% Optional numeric warm starts are supplied in memory by the calling script.
% They are loaded before GA begins; no candidate evaluation reads a file.
if isfield(cfg.ga, 'additional_seed_designs') && ...
        ~isempty(cfg.ga.additional_seed_designs)
    extra = double(cfg.ga.additional_seed_designs);
    assert(size(extra, 2) == nvars, 'Additional STACI seed width mismatch');
    for seed_index = 1:size(extra, 1)
        candidate_x(end + 1, :) = min(max(extra(seed_index, :), lb), ub); %#ok<AGROW>
        candidate_names(end + 1, 1) = "additional in-memory seed"; %#ok<AGROW>
    end
end
if strcmp(cfg.id, 'anytown') && ...
        isfield(cfg.ga, 'feasible_interpolation_to_upper')
    proposed = x0 + cfg.ga.feasible_interpolation_to_upper * (ub - x0);
    candidate_x(end + 1, :) = proposed;
    candidate_names(end + 1, 1) = "upper interpolation";
end
rows = min(size(candidate_x, 1), cfg.ga.population_size);
population(1:rows, :) = candidate_x(1:rows, :);

last_x = [];
last_state = struct();
best_seen_x = [];
best_seen_f = inf;
last_generation = 0;
started = tic;
if isfield(cfg.ga, 'maximum_wall_seconds')
    maximum_wall_seconds = cfg.ga.maximum_wall_seconds;
else
    maximum_wall_seconds = 7200;
end
options = optimoptions('ga', ...
    'Display', cfg.ga.display, ...
    'PopulationSize', cfg.ga.population_size, ...
    'MaxGenerations', cfg.ga.max_generations, ...
    'MaxStallGenerations', cfg.ga.max_stall_generations, ...
    'FunctionTolerance', cfg.ga.function_tolerance, ...
    'ConstraintTolerance', cfg.ga.constraint_tolerance, ...
    'NonlinearConstraintAlgorithm', 'penalty', ...
    'InitialPopulationMatrix', population, 'UseParallel', false, ...
    'OutputFcn', @stop_if_too_long);
[best_x, best_f, exitflag, ga_output] = ga( ...
    @fitness, nvars, [], [], [], [], lb, ub, @nonlinear_constraints, options);

% Keep the best *feasible* incumbent even if GA's penalty result is slightly
% infeasible. This is necessary for narrow two-sided Anytown head bands.
candidate_x(end + 1, :) = best_x;
candidate_names(end + 1, 1) = "GA";
if ~isempty(best_seen_x)
    candidate_x(end + 1, :) = best_seen_x;
    candidate_names(end + 1, 1) = "best feasible GA evaluation";
end
best_feasible_f = inf;
best_feasible_x = [];
best_source = "";
for k = 1:size(candidate_x, 1)
    state = evaluate(candidate_x(k, :));
    if state.violation <= cfg.ga.constraint_tolerance && ...
            state.fitness < best_feasible_f
        best_feasible_f = state.fitness;
        best_feasible_x = candidate_x(k, :);
        best_source = candidate_names(k);
    end
end
if isempty(best_feasible_x)
    error('wdn:NoFeasibleStaciDesign', ...
        '%s/%s: no candidate satisfies pressure and chlorine constraints', ...
        cfg.id, objective_name);
end
state = evaluate(best_feasible_x, true);
result.network_id = cfg.id;
result.objective = char(objective_name);
result.design_link_ids = cellstr(design_ids);
result.design_diameters = best_feasible_x;
result.max_constraint_violation = state.violation;
result.metrics = state.metrics;
result.constraint_consumer_ids = cellstr(consumer_ids);
result.minimum_constraint_demand_m3s = threshold_m3s;
result.minimum_constraint_chlorine_mgL = 0.2;
result.model = 'staci_steady_first_order';
result.optimizer = 'matlab_ga_staci_mex';
if strcmp(cfg.id,'anytown')
    result.pressure_to_head_ft_per_psi=cfg.pressure_to_head;
    result.nominal_pressure_anchor_node_ids=cfg.pressure_anchor_node_ids;
end
result.ga_last_generation = last_generation;
result.maximum_wall_seconds = maximum_wall_seconds;
[~,input_stem,input_extension]=fileparts(input_file);
result.input_file = fullfile('networks', cfg.id, 'input', ...
    [input_stem input_extension]);
result.ga_fval = best_f;
result.optimizer_value = best_feasible_f;
result.incumbent_source = char(best_source);
result.exitflag = exitflag;
result.output = ga_output;
result.elapsed_time_seconds = toc(started);
result.random_seed = cfg.ga.random_seed;
result.ga_max_generations = cfg.ga.max_generations;
result.ga_population_size = cfg.ga.population_size;
if ~isempty(weighting_field)
    result.(weighting_field) = cfg.(weighting_field);
end
if isfield(cfg.ga, 'anchor_numerical_guard_ft')
    result.anchor_numerical_guard_ft = cfg.ga.anchor_numerical_guard_ft;
else
    result.anchor_numerical_guard_ft = 0;
end
if isfield(cfg.ga,'pressure_numerical_guard_psi')
    result.pressure_guard_psi=cfg.ga.pressure_numerical_guard_psi;
end
% Published plotting and tables use the INP's EPANET link order. The
% template comes directly from the input, never from an archived result.
result.full_link_ids = cellstr(input_link_ids);
result.full_diameters = input_diameters(:)';
[found_design, positions] = ismember(design_ids,input_link_ids);
assert(all(found_design), 'Design links missing from INP link order');
result.full_diameters(positions) = best_feasible_x;
result.metrics.full_diameters = result.full_diameters;
link_state = staci.linkResults();
[found_links, link_positions] = ismember( ...
    input_link_ids, string(link_state.id(:)));
assert(all(found_links), 'INP link order contains an unknown STACI link');
if strcmp(cfg.id, 'anytown')
    flow_scale = 6.30901964e-5;
    result.metrics.heads = result.metrics.heads_m / 0.3048;
elseif strcmp(cfg.id, 'tanyimboh_templeman')
    flow_scale = 1 / 3600;
    result.metrics.heads = result.metrics.heads_m;
else
    flow_scale = 0.001;
    result.metrics.heads = result.metrics.heads_m;
end
result.metrics.flows = double(link_state.flow_rate_m3s(link_positions)) / flow_scale;
result.created_at = datetime('now', 'TimeZone', 'local');
if nargin >= 4 && strlength(string(output_file)) > 0
    if ~isfolder(fileparts(output_file)), mkdir(fileparts(output_file)); end
    save(output_file, 'result', '-v7');
end
fprintf('%s/%s: best %.9g, violation %.3g, source %s, %.1f s\n', ...
    cfg.id, objective_name, best_feasible_f, state.violation, best_source, ...
    result.elapsed_time_seconds);

    function value = fitness(x)
        state_now = evaluate(x);
        value = state_now.fitness;
    end

    function [c, ceq] = nonlinear_constraints(x)
        state_now = evaluate(x);
        c = state_now.constraints;
        ceq = [];
    end

    function [ga_state, options_now, optchanged] = stop_if_too_long(options_now, ga_state, flag)
        optchanged = false;
        if strcmp(flag, 'iter')
            last_generation = ga_state.Generation;
        end
        if toc(started) >= maximum_wall_seconds
            ga_state.StopFlag = 'wall-clock budget reached';
        end
    end

    function state_now = evaluate(x, with_metrics)
        if nargin < 2, with_metrics = false; end
        x = double(x(:)');
        if isequal(x, last_x) && ...
                (~with_metrics || isfield(last_state.metrics, 'cost'))
            state_now = last_state;
            return;
        end
        state_now.fitness = 1e12;
        state_now.constraints = 1e6;
        state_now.violation = 1e6;
        state_now.metrics = struct();
        try
            staci.setLinkProperty(design_ids, 'diameter_m', x * diameter_scale_m);
            status = staci.solveHydraulics();
            if ~status.converged
                last_x = x; last_state = state_now; return;
            end
            hydraulic = staci.nodeResults();
            [~, pidx] = ismember(pressure_ids, string(hydraulic.id(:)));
            pressure = double(hydraulic.pressure_head_m(:));
            if strcmp(cfg.id, 'anytown')
                pressure = pressure / (0.3048 * cfg.pressure_to_head);
            end
            lower_pressure=cfg.minimum_pressure;
            upper_pressure=cfg.maximum_pressure;
            if isfield(cfg.ga,'pressure_numerical_guard_psi')
                lower_pressure=lower_pressure+ ...
                    cfg.ga.pressure_numerical_guard_psi;
                upper_pressure=upper_pressure- ...
                    cfg.ga.pressure_numerical_guard_psi;
            end
            constraints = lower_pressure - pressure(pidx);
            if isfinite(cfg.maximum_pressure)
                constraints = [constraints; pressure(pidx) - upper_pressure];
            end
            if isfield(cfg, 'pressure_anchor_node_ids') && ...
                    ~isempty(cfg.pressure_anchor_node_ids)
                [~, aidx] = ismember(string(cfg.pressure_anchor_node_ids), ...
                    string(hydraulic.id(:)));
                anchor_head_ft = hydraulic.total_head_m(aidx) / 0.3048;
                anchor_limit = cfg.pressure_anchor_head_tolerance;
                if isfield(cfg.ga, 'anchor_numerical_guard_ft')
                    anchor_limit = anchor_limit - cfg.ga.anchor_numerical_guard_ft;
                end
                constraints = [constraints; ...
                    abs(anchor_head_ft(:) - cfg.pressure_anchor_target_heads(:)) ...
                    - anchor_limit];
            end
            q_mgL = [];
            cidx = [];
            concentration_sum = NaN;
            if chlorine_objective || with_metrics
                quality = staci.solveSteadyQuality('chemical');
                q_mgL = 1000 * double(quality.node_concentration_kgm3(:));
                [~, cidx] = ismember(consumer_ids, string(quality.node_ids(:)));
                [~, qidx] = ismember(quality_ids, string(quality.node_ids(:)));
                concentration_sum = sum(q_mgL(qidx).^2);
                if chlorine_objective
                    constraints = [constraints; 0.2 - q_mgL(cidx)];
                end
            end
            switch string(objective_name)
                case "cost"
                    score = wdn.pipe_cost(x, lengths, cfg);
                case "hydraulic_entropy"
                    score = wdn.staci_flow_entropy(staci, cfg, []);
                case {"source_distance_weighted_entropy", ...
                        "branch_hop_weighted_entropy"}
                    score = wdn.source_distance_weighted_entropy(staci, cfg, ...
                        nodal_split_weights);
                case "chlorine_concentration"
                    score = concentration_sum;
                case "chlorine_entropy"
                    score = wdn.staci_chlorine_entropy(staci, cfg, q_mgL);
                case "todini"
                    score = wdn.staci_todini_index(staci, cfg);
            end
            assert(isfinite(score), 'Non-finite chlorine objective');
            state_now.constraints = constraints(:);
            state_now.violation = max([0; constraints(:)]);
            if strcmp(objective_name, 'cost')
                state_now.fitness = score;
            else
                state_now.fitness = -score;
            end
            if state_now.violation <= cfg.ga.constraint_tolerance && ...
                    state_now.fitness < best_seen_f
                best_seen_x = x;
                best_seen_f = state_now.fitness;
            end
            if with_metrics
                link_state = staci.linkResults();
                state_now.metrics.cost = wdn.pipe_cost(x, lengths, cfg);
                state_now.metrics.chlorine_concentration = concentration_sum;
                state_now.metrics.chlorine_entropy = ...
                    wdn.staci_chlorine_entropy(staci, cfg, q_mgL);
                state_now.metrics.hydraulic_entropy = ...
                    wdn.staci_flow_entropy(staci, cfg, []);
                if ~isempty(weighting_field)
                    state_now.metrics.(char(objective_name)) = score;
                end
                state_now.metrics.todini = wdn.staci_todini_index(staci, cfg);
                state_now.metrics.node_ids = cellstr(string(hydraulic.id(:)));
                state_now.metrics.pressures = pressure;
                state_now.metrics.heads_m = double(hydraulic.total_head_m(:));
                state_now.metrics.chlorine = q_mgL;
                state_now.metrics.link_ids = cellstr(string(link_state.id(:)));
                state_now.metrics.flows_m3s = double(link_state.flow_rate_m3s(:));
                state_now.metrics.minimum_consumer_chlorine_mgL = min(q_mgL(cidx));
            end
        catch exception
            warning('wdn:StaciCandidateFailed', '%s', exception.message);
        end
        last_x = x;
        last_state = state_now;
    end
end
