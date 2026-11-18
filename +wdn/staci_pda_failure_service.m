function [summary, scenarios] = staci_pda_failure_service(cfg, diameters, label, dda_file, pda_file)
%STACI_PDA_FAILURE_SERVICE Demand-weighted N-1 service from STACI PDA.
% Requested demand is read from the imported fixed-load DDA-format INP
% without a DDA hydraulic solve. Every intact/failure hydraulic run uses PDA.
pda = StaciModel(pda_file);
pda_cleanup = onCleanup(@() pda.release());
if strcmp(cfg.id, 'anytown'), scale = 0.0254; else, scale = 0.001; end
design_ids = string(cfg.design_link_ids(:));
x_m = double(diameters(:)) * scale;
pda.setLinkProperty(design_ids, 'diameter_m', x_m);
node_ids = string(cfg.stress.node_ids(:));
failed_ids = string(cfg.stress.failed_link_ids(:));
base = StaciModel(dda_file);
base_cleanup = onCleanup(@() base.release());
requested = max(double(base.getNodeProperty(node_ids,'demand_m3s')), 0);
requested = requested(:);
clear base_cleanup base
assert(sum(requested) > 0, 'No requested consumer demand');
if ~isfield(cfg.stress,'disabled_link_ids') || ...
        isempty(cfg.stress.disabled_link_ids)
    status = pda.solveHydraulics();
    assert(status.converged, 'Intact PDA hydraulics failed');
end
n = numel(failed_ids);
delivered_fraction = zeros(n,1);
quality_fraction = zeros(n,1);
pressure_bad_fraction = ones(n,1);
overdelivery_nodes = zeros(n,1);
max_overdelivery = zeros(n,1);
nonconvergent = false(n,1);
fallback_used = false(n,1);
mass_tolerance_kg_s = 1e-8*ones(n,1);
message = strings(n,1);
for k = 1:n
    try
        % Close the failed pipe and remove any source-disconnected island.
        % Each remaining connected case is solved with PDA only; a fresh
        % resident model prevents a failed Newton iterate from carrying to
        % the next case. The temporary INP is used in replay, never in GA.
        [delivered,pressure,concentration,fallback_used(k), ...
            mass_tolerance_kg_s(k)] = ...
            wdn.staci_connected_outage_outputs(cfg,diameters, ...
            pda_file,failed_ids(k),node_ids,'pda');
        delivered = max(delivered,0);
        excess = max(delivered - requested, 0);
        overdelivery_nodes(k) = nnz(excess > 1e-6);
        max_overdelivery(k) = max(excess);
        delivered = min(delivered, requested);
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
end
scenarios = table(repmat(string(label),n,1), failed_ids, ...
    delivered_fraction, quality_fraction, pressure_bad_fraction, ...
    overdelivery_nodes, max_overdelivery, nonconvergent, ...
    fallback_used, mass_tolerance_kg_s, message, ...
    'VariableNames', {'Topology','FailedLinkID','DeliveredDemandFraction', ...
    'QualityCompliantDemandFraction','PressureViolationFraction', ...
    'OverdeliveryNodeCount','MaxOverdelivery','Nonconvergent', ...
    'SolverToleranceFallback','ContinuityToleranceKgS','ErrorMessage'});
summary = table(string(label), n, sum(requested), ...
    mean(delivered_fraction), min(delivered_fraction), ...
    mean(quality_fraction), min(quality_fraction), ...
    mean(pressure_bad_fraction), max(max_overdelivery), nnz(nonconvergent), ...
    'VariableNames', {'Topology','FailedPipeCount','RequestedDemand', ...
    'MeanDeliveredDemandFraction','WorstDeliveredDemandFraction', ...
    'MeanQualityCompliantDemandFraction','WorstQualityCompliantDemandFraction', ...
    'MeanPressureViolationFraction','MaxOverdelivery','NonconvergentScenarioCount'});
clear pda_cleanup
end
