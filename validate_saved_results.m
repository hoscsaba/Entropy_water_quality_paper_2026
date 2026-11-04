function report = validate_saved_results
%VALIDATE_SAVED_RESULTS Re-evaluate every production design through EPANET.
%   This performs no optimization and does not modify saved MAT files.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_ids = ["tanyimboh_templeman", "anytown", "balerma"];
rows = cell(0, 7);
metric_relative_tolerance = 1e-6;

for network_index = 1:numel(network_ids)
    network_dir = fullfile(root, 'networks', char(network_ids(network_index)));
    addpath(network_dir);
    clear network_config;
    cfg = network_config(network_dir);
    path_cleanup = onCleanup(@() rmpath(network_dir));
    wdn.setup_toolkit(cfg);
    [d, model] = wdn.open_network(cfg);
    network_cleanup = onCleanup(@() d.unload);

    for objective_index = 1:numel(cfg.objectives)
        objective = string(cfg.objectives{objective_index});
        saved = load(fullfile(cfg.results_dir, objective + ".mat"), 'result');
        recalculated = wdn.evaluate_design( ...
            d, saved.result.design_diameters, cfg, model, true);
        stored = saved.result.metrics;
        stored_values = [stored.cost, stored.hydraulic_entropy, ...
            stored.chlorine_concentration, stored.chlorine_entropy, stored.todini];
        new_values = [recalculated.cost, recalculated.hydraulic_entropy, ...
            recalculated.chlorine_concentration, recalculated.chlorine_entropy, ...
            recalculated.todini];
        relative_error = max(abs(new_values - stored_values) ./ ...
            max(abs(stored_values), 1));
        [c, ceq] = wdn.pressure_constraints( ...
            saved.result.design_diameters, d, cfg, model);
        violation = max([0; c(:); abs(ceq(:))]);
        rows(end + 1, :) = {network_ids(network_index), objective, ...
            relative_error, violation, stored_values(1), stored_values(2), ...
            stored_values(4)}; %#ok<AGROW>
        if relative_error > metric_relative_tolerance
            error('release:MetricRegression', ...
                '%s/%s changed by relative %.3g.', ...
                network_ids(network_index), objective, relative_error);
        end
        if violation > cfg.ga.constraint_tolerance
            error('release:FeasibilityRegression', ...
                '%s/%s violates pressure constraints by %.3g.', ...
                network_ids(network_index), objective, violation);
        end
    end
    clear network_cleanup d model path_cleanup;
end

report = cell2table(rows, 'VariableNames', {'Network','Objective', ...
    'MaximumRelativeMetricError','MaximumConstraintViolation', ...
    'Cost','HydraulicEntropy','ChlorineEntropy'});
disp(report(:, 1:4));
fprintf('All %d saved designs reproduce and remain pressure-feasible.\n', ...
    height(report));
end
