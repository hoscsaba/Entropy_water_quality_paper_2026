function [summary, scenarios] = pipe_failure_stress_test(cfg, design_diameters, topology_name)
%PIPE_FAILURE_STRESS_TEST Close each configured pipe and assess service loss.
%
% The stress test uses the same EPANET hydraulic and 48 h chlorine settings
% as the objective evaluation. Fractions are evaluated over every combination
% of failed pipe and configured assessment node. Reservoirs and tanks are not
% included unless they are explicitly listed in cfg.stress.node_ids.

arguments
    cfg (1,1) struct
    design_diameters (1,:) double
    topology_name (1,1) string
end

if ~isfield(cfg, 'stress') || ~isstruct(cfg.stress)
    error('wdn:StressConfig', 'Missing cfg.stress configuration structure.');
end
required_fields = {'failed_link_ids','node_ids','minimum_chlorine'};
for k = 1:numel(required_fields)
    if ~isfield(cfg.stress, required_fields{k})
        error('wdn:StressConfig', 'Missing cfg.stress.%s.', required_fields{k});
    end
end

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
wdn.apply_design(d, design_diameters, cfg, model);

link_ids = string(d.getLinkNameID);
node_ids = string(d.getNodeNameID);
[links_found, failed_link_indices] = ismember(string(cfg.stress.failed_link_ids), link_ids);
[nodes_found, assessment_node_indices] = ismember(string(cfg.stress.node_ids), node_ids);
if ~all(links_found)
    error('wdn:StressUnknownLink', 'Unknown failed link(s): %s', ...
        strjoin(string(cfg.stress.failed_link_ids(~links_found)), ', '));
end
if ~all(nodes_found)
    error('wdn:StressUnknownNode', 'Unknown assessment node(s): %s', ...
        strjoin(string(cfg.stress.node_ids(~nodes_found)), ', '));
end

initial_status = double(d.getLinkInitialStatus);
n_failures = numel(failed_link_indices);
n_nodes = numel(assessment_node_indices);
pressures = nan(n_failures, n_nodes);
chlorine = nan(n_failures, n_nodes);
hydraulic_failed = false(n_failures, 1);
error_messages = strings(n_failures, 1);

previous_dir = pwd;
cd(cfg.runtime_dir);
directory_cleanup = onCleanup(@() cd(previous_dir));

for failure = 1:n_failures
    failed_index = failed_link_indices(failure);
    try
        % Restore all statuses because EPANET can change current link states
        % during a preceding simulation, then close exactly one physical pipe.
        d.setLinkInitialStatus(initial_status);
        d.setLinkStatus(initial_status);
        d.setLinkInitialStatus(failed_index, 0);
        d.setLinkStatus(failed_index, 0);

        d.solveCompleteHydraulics;
        pressure_raw = double(d.getNodePressure);
        pressures(failure, :) = pressure_raw(assessment_node_indices);

        chlorine_raw = wdn.chlorine_state(d, cfg);
        chlorine(failure, :) = chlorine_raw(assessment_node_indices);
    catch exception
        % A non-convergent/disconnected scenario represents complete service
        % failure at the assessed nodes and remains visible in the detail CSV.
        hydraulic_failed(failure) = true;
        error_messages(failure) = string(exception.message);
        pressures(failure, :) = -inf;
        chlorine(failure, :) = 0;
    end
end

pressure_violations = pressures < cfg.minimum_pressure | ...
    pressures > cfg.maximum_pressure | ~isfinite(pressures);
chlorine_violations = chlorine < cfg.stress.minimum_chlorine | ...
    ~isfinite(chlorine);
valid_chlorine = chlorine(isfinite(chlorine));

summary.topology = topology_name;
summary.failed_pipe_count = n_failures;
summary.assessment_node_count = n_nodes;
summary.scenario_node_count = n_failures * n_nodes;
summary.pressure_violation_count = nnz(pressure_violations);
summary.pressure_violation_fraction = mean(pressure_violations, 'all');
summary.chlorine_violation_count = nnz(chlorine_violations);
summary.chlorine_violation_fraction = mean(chlorine_violations, 'all');
summary.mean_chlorine_mg_L = mean(valid_chlorine);
summary.std_chlorine_mg_L = std(valid_chlorine, 0);
summary.chlorine_cv_fraction = summary.std_chlorine_mg_L / summary.mean_chlorine_mg_L;
summary.nonconvergent_scenario_count = nnz(hydraulic_failed);
summary.minimum_pressure_psi = min(pressures, [], 'all');
summary.minimum_chlorine_mg_L = min(chlorine, [], 'all');

scenario_topology = repmat(topology_name, n_failures, 1);
failed_link_id = string(cfg.stress.failed_link_ids(:));
pressure_violation_count = sum(pressure_violations, 2);
chlorine_violation_count = sum(chlorine_violations, 2);
mean_chlorine_mg_L = mean(chlorine, 2);
minimum_pressure_psi = min(pressures, [], 2);
minimum_chlorine_mg_L = min(chlorine, [], 2);
scenarios = table(scenario_topology, failed_link_id, hydraulic_failed, ...
    pressure_violation_count, chlorine_violation_count, mean_chlorine_mg_L, ...
    minimum_pressure_psi, minimum_chlorine_mg_L, error_messages, ...
    'VariableNames', {'Topology','FailedLinkID','Nonconvergent', ...
    'PressureViolationCount','ChlorineViolationCount','MeanChlorine_mg_L', ...
    'MinimumPressure_psi','MinimumChlorine_mg_L','ErrorMessage'});

clear directory_cleanup cleanup
end
