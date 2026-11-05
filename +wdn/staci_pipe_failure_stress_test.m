function [summary, scenarios] = staci_pipe_failure_stress_test(cfg, diameters, label, input_file)
%STACI_PIPE_FAILURE_STRESS_TEST DDA N-1 replay in one resident STACI model.
st = StaciModel(input_file);
cleanup = onCleanup(@() st.release());
if strcmp(cfg.id, 'anytown'), scale = 0.0254; else, scale = 0.001; end
st.setLinkProperty(string(cfg.design_link_ids(:)), 'diameter_m', ...
    double(diameters(:)) * scale);
failed_ids = string(cfg.stress.failed_link_ids(:));
node_ids = string(cfg.stress.node_ids(:));
n_fail = numel(failed_ids);
n_node = numel(node_ids);
pressures = nan(n_fail, n_node);
chlorine = nan(n_fail, n_node);
failed = false(n_fail, 1);
messages = strings(n_fail, 1);
original_status = st.getLinkProperty(failed_ids, 'status');
restore = onCleanup(@() st.setLinkProperty(failed_ids, 'status', original_status));
for k = 1:n_fail
    if ~strcmp(cfg.id,'balerma')
        st.setLinkProperty(failed_ids(k), 'status', 0);
    end
    try
        if strcmp(cfg.id,'balerma')
            [~,p,c] = wdn.staci_connected_outage_outputs( ...
                cfg,diameters,input_file,failed_ids(k),node_ids,'dda');
        else
            status = st.solveHydraulics();
            assert(status.converged, 'STACI hydraulics did not converge');
            state = st.nodeResults();
            [found, ni] = ismember(node_ids, string(state.id(:)));
            assert(all(found), 'Assessment node missing');
            p = double(state.pressure_head_m(ni));
            if strcmp(cfg.id, 'anytown')
                p = p / (0.3048 * cfg.pressure_to_head);
            end
            quality = st.solveSteadyQuality('chemical');
            [found_quality, qi] = ismember(node_ids, string(quality.node_ids(:)));
            assert(all(found_quality), 'Quality node missing');
            c = 1000 * double(quality.node_concentration_kgm3(qi));
        end
        assert(all(isfinite(c(:))) && all(isfinite(p(:)) | isinf(p(:))), ...
            'Non-finite STACI result');
        pressures(k,:) = p(:)';
        chlorine(k,:) = c(:)';
    catch exception
        failed(k) = true;
        messages(k) = string(exception.message);
        pressures(k,:) = -inf;
        chlorine(k,:) = 0;
    end
    if ~strcmp(cfg.id,'balerma')
        st.setLinkProperty(failed_ids(k), 'status', original_status(k));
    end
end

pressure_bad = pressures < cfg.minimum_pressure | ...
    pressures > cfg.maximum_pressure | ~isfinite(pressures);
chlorine_bad = chlorine < cfg.stress.minimum_chlorine | ~isfinite(chlorine);
finite_c = chlorine(isfinite(chlorine));
summary.topology = string(label);
summary.failed_pipe_count = n_fail;
summary.assessment_node_count = n_node;
summary.scenario_node_count = n_fail * n_node;
summary.pressure_violation_count = nnz(pressure_bad);
summary.pressure_violation_fraction = mean(pressure_bad, 'all');
summary.chlorine_violation_count = nnz(chlorine_bad);
summary.chlorine_violation_fraction = mean(chlorine_bad, 'all');
summary.mean_chlorine_mg_L = mean(finite_c);
summary.std_chlorine_mg_L = std(finite_c, 0);
summary.chlorine_cv_fraction = summary.std_chlorine_mg_L / summary.mean_chlorine_mg_L;
summary.nonconvergent_scenario_count = nnz(failed);
summary.minimum_pressure_psi = min(pressures, [], 'all');
summary.minimum_chlorine_mg_L = min(chlorine, [], 'all');
scenarios = table(repmat(string(label),n_fail,1), failed_ids, failed, ...
    sum(pressure_bad,2), sum(chlorine_bad,2), mean(chlorine,2), ...
    min(pressures,[],2), min(chlorine,[],2), messages, ...
    'VariableNames', {'Topology','FailedLinkID','Nonconvergent', ...
    'PressureViolationCount','ChlorineViolationCount','MeanChlorine_mg_L', ...
    'MinimumPressure_psi','MinimumChlorine_mg_L','ErrorMessage'});
clear restore cleanup
end
