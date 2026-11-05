function [summary, scenarios] = staci_pda_failure_service(cfg, diameters, label, dda_file, pda_file)
%STACI_PDA_FAILURE_SERVICE Demand-weighted N-1 service from STACI PDA.
% The intact DDA model supplies requested demand. The resident PDA model
% provides delivered demand after each pipe closure. No model file is
% written or read during the outage loop.
dda = StaciModel(dda_file);
dda_cleanup = onCleanup(@() dda.release());
pda = StaciModel(pda_file);
pda_cleanup = onCleanup(@() pda.release());
if strcmp(cfg.id, 'anytown'), scale = 0.0254; else, scale = 0.001; end
design_ids = string(cfg.design_link_ids(:));
x_m = double(diameters(:)) * scale;
dda.setLinkProperty(design_ids, 'diameter_m', x_m);
pda.setLinkProperty(design_ids, 'diameter_m', x_m);
status = dda.solveHydraulics();
assert(status.converged, 'Intact DDA hydraulics failed');
intact = dda.nodeResults();
node_ids = string(cfg.stress.node_ids(:));
failed_ids = string(cfg.stress.failed_link_ids(:));
[found, ni] = ismember(node_ids, string(intact.id(:)));
assert(all(found), 'Service node missing');
requested = max(double(intact.demand_m3s(ni)), 0);
assert(sum(requested) > 0, 'No requested consumer demand');
status = pda.solveHydraulics();
assert(status.converged, 'Intact PDA hydraulics failed');
n = numel(failed_ids);
delivered_fraction = zeros(n,1);
quality_fraction = zeros(n,1);
pressure_bad_fraction = ones(n,1);
overdelivery_nodes = zeros(n,1);
max_overdelivery = zeros(n,1);
nonconvergent = false(n,1);
message = strings(n,1);
original_status = pda.getLinkProperty(failed_ids, 'status');
restore = onCleanup(@() pda.setLinkProperty(failed_ids, 'status', original_status));
for k = 1:n
    if ~strcmp(cfg.id,'balerma')
        pda.setLinkProperty(failed_ids(k), 'status', 0);
    end
    try
        if strcmp(cfg.id,'balerma')
            [delivered,pressure,concentration] = ...
                wdn.staci_connected_outage_outputs(cfg,diameters, ...
                pda_file,failed_ids(k),node_ids,'pda');
            delivered = max(delivered,0);
        else
            status = pda.solveHydraulics();
            assert(status.converged, 'PDA hydraulics did not converge');
            state = pda.nodeResults();
            [found, pi] = ismember(node_ids, string(state.id(:)));
            assert(all(found), 'Service node missing after outage');
            delivered = max(double(state.demand_m3s(pi)), 0);
            quality = pda.solveSteadyQuality('chemical');
            [found_quality, qi] = ismember(node_ids, string(quality.node_ids(:)));
            assert(all(found_quality), 'Quality node missing after outage');
            concentration = 1000 * double(quality.node_concentration_kgm3(qi));
            pressure = double(state.pressure_head_m(pi));
        end
        excess = max(delivered - requested, 0);
        overdelivery_nodes(k) = nnz(excess > 1e-6);
        max_overdelivery(k) = max(excess);
        delivered = min(delivered, requested);
        if strcmp(cfg.id, 'anytown')
            pressure = pressure / (0.3048 * cfg.pressure_to_head);
        end
        assert(all(isfinite([delivered(:);concentration(:)])) && ...
            all(isfinite(pressure(:)) | isinf(pressure(:))), ...
            'Non-finite PDA output');
        delivered_fraction(k) = sum(delivered) / sum(requested);
        quality_fraction(k) = sum(delivered .* ...
            (concentration >= cfg.stress.minimum_chlorine)) / sum(requested);
        pressure_bad_fraction(k) = mean(pressure < cfg.minimum_pressure | ...
            pressure > cfg.maximum_pressure);
    catch exception
        nonconvergent(k) = true;
        message(k) = string(exception.message);
    end
    if ~strcmp(cfg.id,'balerma')
        pda.setLinkProperty(failed_ids(k), 'status', original_status(k));
    end
end
scenarios = table(repmat(string(label),n,1), failed_ids, ...
    delivered_fraction, quality_fraction, pressure_bad_fraction, ...
    overdelivery_nodes, max_overdelivery, nonconvergent, message, ...
    'VariableNames', {'Topology','FailedLinkID','DeliveredDemandFraction', ...
    'QualityCompliantDemandFraction','PressureViolationFraction', ...
    'OverdeliveryNodeCount','MaxOverdelivery','Nonconvergent','ErrorMessage'});
summary = table(string(label), n, sum(requested), ...
    mean(delivered_fraction), min(delivered_fraction), ...
    mean(quality_fraction), min(quality_fraction), ...
    mean(pressure_bad_fraction), max(max_overdelivery), nnz(nonconvergent), ...
    'VariableNames', {'Topology','FailedPipeCount','RequestedDemand', ...
    'MeanDeliveredDemandFraction','WorstDeliveredDemandFraction', ...
    'MeanQualityCompliantDemandFraction','WorstQualityCompliantDemandFraction', ...
    'MeanPressureViolationFraction','MaxOverdelivery','NonconvergentScenarioCount'});
clear restore pda_cleanup dda_cleanup
end
