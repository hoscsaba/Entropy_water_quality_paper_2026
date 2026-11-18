function [demand,pressure,chlorine,used_fallback,mass_tolerance_kg_s] = staci_connected_outage_outputs( ...
        cfg,diameters,input_file,failed_id,assessment_ids,case_kind)
%STACI_CONNECTED_OUTAGE_OUTPUTS Solve source-connected part of a pipe outage.
% Source-disconnected nodes have zero delivery/concentration and no pressure
% reference. Their pressure is recorded as -Inf for violation statistics.
% Separate MATLAB processes may replay different designs concurrently.
% Their outage INPs must never share a path: otherwise one case can be
% imported while another process is rewriting the same file.
case_name=sprintf('%s_connected_outage_%d.inp', ...
    char(case_kind),feature('getpid'));
case_file=fullfile(cfg.results_dir,'runtime',case_name);
used_fallback=false;
mass_tolerance_kg_s=1e-8;
% A design pipe exactly at the lower diameter bound is the continuous
% optimizer's removal surrogate. Remove it from the outage graph before
% finding source-connected components; otherwise an almost-zero-capacity
% edge can leave a nominally connected island and a singular PDA solve.
design_ids = string(cfg.design_link_ids(:));
removal_threshold=cfg.minimum_diameter*(1+1e-4);
if isfield(cfg.stress,'removal_diameter_threshold')
    removal_threshold=cfg.stress.removal_diameter_threshold;
end
removed = design_ids(double(diameters(:)) <= removal_threshold);
% Protected direct reservoir connectors remain present in the failure
% graph even when an optimizer selected the minimum allowed diameter.
% Protection means no closure in this replay; the actual small diameter
% still limits its hydraulic capacity in the subsequent PDA solve.
if isfield(cfg.stress,'protected_link_ids') && ...
        ~isempty(cfg.stress.protected_link_ids)
    protected=string(cfg.stress.protected_link_ids(:));
    assert(all(ismember(protected,design_ids)), ...
        'Protected reservoir connector is not a design pipe');
    removed=setdiff(removed,protected,'stable');
end
if isfield(cfg.stress,'disabled_link_ids')
    disabled=string(cfg.stress.disabled_link_ids(:));
    assert(all(ismember(disabled,design_ids)), ...
        'Unavailable-reservoir connector is not a physical pipe');
    removed=unique([removed;disabled],'stable');
end
require_fixed_head=isfield(cfg.stress,'require_fixed_head_source') && ...
    cfg.stress.require_fixed_head_source;
connected_ids=wdn.write_staci_connected_outage_input( ...
    input_file,failed_id,case_file,removed,require_fixed_head);
if isempty(connected_ids)
    demand=zeros(numel(assessment_ids),1);
    pressure=-inf(numel(assessment_ids),1);
    chlorine=zeros(numel(assessment_ids),1);
    return
end
st = StaciModel(case_file);
cleanup = onCleanup(@() st.release()); %#ok<NASGU>
case_links = st.linkIds();
[in_case,di] = ismember(case_links,design_ids);
if strcmp(cfg.id,'anytown'),diameter_scale=0.0254;
else,diameter_scale=0.001;end
st.setLinkProperty(case_links(in_case),'diameter_m', ...
    double(diameters(di(in_case))) * diameter_scale);
status = st.solveHydraulics();
if ~status.converged && isfield(cfg.stress,'allow_pda_tolerance_fallback') && ...
        cfg.stress.allow_pda_tolerance_fallback && strcmp(case_kind,'pda')
    % Near zero delivered demand, a tiny physical pipe can make the PDA
    % Jacobian ill-conditioned. Retry the identical case with more Newton
    % steps and two bounded RMS continuity tolerances. No pipe, source,
    % chlorine, demand-model or pressure setting is changed.
    clear cleanup st
    content=fileread(case_file);
    relaxed=regexprep(content,'(?m)^[ \t]*TRIALS[ \t]+[0-9]+[ \t]*$', ...
        ' TRIALS 2000');
    assert(~strcmp(content,relaxed),'Outage INP has no TRIALS option');
    fid=fopen(case_file,'w');
    assert(fid>0,'Cannot write fallback outage INP');
    file_cleanup=onCleanup(@()fclose(fid));
    fwrite(fid,relaxed,'char');
    clear file_cleanup
    for tolerance=[1e-3,1e-2]
        st=StaciModel(case_file);
        cleanup=onCleanup(@()st.release()); %#ok<NASGU>
        st.setLinkProperty(case_links(in_case),'diameter_m', ...
            double(diameters(di(in_case))) * diameter_scale);
        st.setSolverTolerances(1e-4,tolerance);
        status=st.solveHydraulics();
        if status.converged
            used_fallback=true;
            mass_tolerance_kg_s=tolerance;
            break
        end
        clear cleanup st
    end
end
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
