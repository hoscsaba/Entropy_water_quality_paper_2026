function [demand,pressure,chlorine] = staci_connected_outage_outputs( ...
        cfg,diameters,input_file,failed_id,assessment_ids,case_kind)
%STACI_CONNECTED_OUTAGE_OUTPUTS Solve source-connected part of a pipe outage.
% Source-disconnected nodes have zero delivery/concentration and no pressure
% reference. Their pressure is recorded as -Inf for violation statistics.
case_file = fullfile(cfg.results_dir,'runtime', ...
    [char(case_kind) '_connected_outage.inp']);
wdn.write_staci_connected_outage_input(input_file,failed_id,case_file);
st = StaciModel(case_file);
cleanup = onCleanup(@() st.release()); %#ok<NASGU>
design_ids = string(cfg.design_link_ids(:));
case_links = st.linkIds();
[in_case,di] = ismember(case_links,design_ids);
st.setLinkProperty(case_links(in_case),'diameter_m', ...
    double(diameters(di(in_case))) * 0.001);
status = st.solveHydraulics();
assert(status.converged,'Source-connected STACI outage hydraulics failed');
nodes = st.nodeResults();
quality = st.solveSteadyQuality('chemical');
assessment_ids = string(assessment_ids(:));
demand = zeros(numel(assessment_ids),1);
pressure = -inf(numel(assessment_ids),1);
chlorine = zeros(numel(assessment_ids),1);
[found,ni] = ismember(assessment_ids,string(nodes.id(:)));
[qfound,qi] = ismember(assessment_ids,string(quality.node_ids(:)));
assert(isequal(found,qfound),'Connected node alignment mismatch');
demand(found) = double(nodes.demand_m3s(ni(found)));
pressure(found) = double(nodes.pressure_head_m(ni(found)));
chlorine(found) = 1000 * double(quality.node_concentration_kgm3(qi(found)));
end
