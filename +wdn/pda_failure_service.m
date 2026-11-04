function [summary, scenarios] = pda_failure_service(cfg, diameters, label)
%PDA_FAILURE_SERVICE Replay saved diameters under single-pipe outages.
% Service fractions use requested demand from the intact DDA state as the
% denominator and actual PDA demand after each outage as the numerator.
% No pipe-failure probabilities are assumed; these are deterministic N-1
% service indicators, not annual reliability probabilities.

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
wdn.apply_design(d, diameters, cfg, model);
node_ids = string(d.getNodeNameID);
link_ids = string(d.getLinkNameID);
[found_nodes, ni] = ismember(string(cfg.stress.node_ids), node_ids);
[found_links, li] = ismember(string(cfg.stress.failed_link_ids), link_ids);
assert(all(found_nodes) && all(found_links), 'Configured service nodes or pipes are missing.');

% The model's demand multiplier and patterns are preserved by reading the
% requested rate from EPANET itself under DDA, before switching to PDA.
d.setDemandModel('DDA', 0, cfg.minimum_pressure, 0.5);
d.solveCompleteHydraulics;
raw = d.getNodeActualDemand;
if iscell(raw), raw = cell2mat(raw); end
requested = max(double(raw(ni)), 0);
requested = requested(:);
assert(all(isfinite(requested)) && sum(requested) > 0, ...
    'Requested service demand must be finite and positive.');

d.setDemandModel('PDA', 0, cfg.minimum_pressure, 0.5);
model_info = d.getDemandModel;
assert(model_info.DemandModelCode == 1, 'EPANET did not activate PDA.');

initial_status = double(d.getLinkInitialStatus);
n = numel(li);
delivered_fraction = nan(n,1);
quality_fraction = nan(n,1);
pressure_violation_fraction = nan(n,1);
nonconvergent = false(n,1);
error_message = strings(n,1);
overdelivery_nodes = zeros(n,1);
max_overdelivery = zeros(n,1);

previous_dir = pwd;
cd(cfg.runtime_dir);
directory_cleanup = onCleanup(@() cd(previous_dir));
for k = 1:n
    try
        d.setLinkInitialStatus(initial_status);
        d.setLinkStatus(initial_status);
        d.setLinkInitialStatus(li(k), 0);
        d.setLinkStatus(li(k), 0);
        d.solveCompleteHydraulics;
        raw_delivered = d.getNodeActualDemand;
        if iscell(raw_delivered), raw_delivered = cell2mat(raw_delivered); end
        delivered = max(double(raw_delivered(ni)), 0);
        delivered = delivered(:);
        % The toolkit can return a positive excess above the prescribed
        % demand at an individual node. Record it as a numerical diagnostic;
        % it cannot count as additional requested service.
        excess = max(delivered - requested, 0);
        overdelivery_nodes(k) = nnz(excess > 1e-3);
        max_overdelivery(k) = max(excess);
        delivered = min(delivered, requested);
        raw_pressure = d.getNodePressure;
        pressure = double(raw_pressure(ni));
        pressure = pressure(:);
        quality_all = wdn.chlorine_state(d, cfg);
        concentration = quality_all(ni);
        concentration = concentration(:);
        assert(all(isfinite(delivered)) && all(isfinite(concentration)), ...
            'Nonfinite PDA service or chlorine result.');
        delivered_fraction(k) = sum(delivered) / sum(requested);
        quality_fraction(k) = sum(delivered .* ...
            (concentration >= cfg.stress.minimum_chlorine)) / sum(requested);
        pressure_violation_fraction(k) = mean(pressure < cfg.minimum_pressure | ...
            pressure > cfg.maximum_pressure | ~isfinite(pressure));
    catch ME
        nonconvergent(k) = true;
        error_message(k) = string(ME.message);
        delivered_fraction(k) = 0;
        quality_fraction(k) = 0;
        pressure_violation_fraction(k) = 1;
    end
end

scenario_topology = repmat(string(label), n, 1);
failed_link_id = string(cfg.stress.failed_link_ids(:));
scenarios = table(scenario_topology, failed_link_id, delivered_fraction, ...
    quality_fraction, pressure_violation_fraction, overdelivery_nodes, ...
    max_overdelivery, nonconvergent, error_message, ...
    'VariableNames', {'Topology','FailedLinkID','DeliveredDemandFraction', ...
    'QualityCompliantDemandFraction','PressureViolationFraction', ...
    'OverdeliveryNodeCount','MaxOverdelivery','Nonconvergent','ErrorMessage'});

summary = table(string(label), n, sum(requested), ...
    mean(delivered_fraction), min(delivered_fraction), ...
    mean(quality_fraction), min(quality_fraction), ...
    mean(pressure_violation_fraction), max(max_overdelivery), nnz(nonconvergent), ...
    'VariableNames', {'Topology','FailedPipeCount','RequestedDemand', ...
    'MeanDeliveredDemandFraction','WorstDeliveredDemandFraction', ...
    'MeanQualityCompliantDemandFraction','WorstQualityCompliantDemandFraction', ...
    'MeanPressureViolationFraction','MaxOverdelivery','NonconvergentScenarioCount'});
clear directory_cleanup cleanup
end
