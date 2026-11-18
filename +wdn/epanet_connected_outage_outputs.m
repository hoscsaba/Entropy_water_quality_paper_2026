function [demand,pressure,chlorine] = epanet_connected_outage_outputs( ...
        cfg,diameters,input_file,failed_id,assessment_ids)
%EPANET_CONNECTED_OUTAGE_OUTPUTS Independent PDA rescue for rare STACI failures.
% Uses the same source-connected outage graph, pipe vector, PDA settings and
% first-order quality INP as STACI. EPANET's 14-day EPS approximates the
% stationary chlorine field. Only use when both STACI tolerance attempts
% failed; the calling replay labels every such case.
design_ids=string(cfg.design_link_ids(:));
removal_threshold=cfg.minimum_diameter*(1+1e-4);
if isfield(cfg.stress,'removal_diameter_threshold')
    removal_threshold=cfg.stress.removal_diameter_threshold;
end
removed=design_ids(double(diameters(:))<=removal_threshold);
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
case_name=sprintf('epanet_pda_connected_outage_%d.inp',feature('getpid'));
case_file=fullfile(cfg.results_dir,'runtime',case_name);
require_fixed_head=isfield(cfg.stress,'require_fixed_head_source') && ...
    cfg.stress.require_fixed_head_source;
connected_ids=wdn.write_staci_connected_outage_input( ...
    input_file,failed_id,case_file,removed,require_fixed_head);
assessment_ids=string(assessment_ids(:));
demand=zeros(numel(assessment_ids),1);
pressure=-inf(numel(assessment_ids),1);
chlorine=zeros(numel(assessment_ids),1);
if isempty(connected_ids),return,end
wdn.setup_toolkit(cfg);
original_dir=pwd;
cd(fileparts(case_file));
restore=onCleanup(@()cd(original_dir)); %#ok<NASGU>
if isfield(cfg,'epanet_library') && ...
        strlength(string(cfg.epanet_library))>0
    ep=epanet(case_name,cfg.epanet_library);
else
    ep=epanet(case_name);
end
release=onCleanup(@()ep.unload()); %#ok<NASGU>
link_ids=string(ep.getLinkNameID); link_ids=link_ids(:);
link_diameters=double(ep.getLinkDiameter);link_diameters=link_diameters(:);
[found,position]=ismember(link_ids,design_ids);
link_diameters(found)=double(diameters(position(found)));
ep.setLinkDiameter(link_diameters);
ep.solveCompleteHydraulics;
ep.solveCompleteQuality;
node_ids=string(ep.getNodeNameID);node_ids=node_ids(:);
[found,position]=ismember(assessment_ids,node_ids);
actual_demand=double(ep.getNodeActualDemand);actual_demand=actual_demand(:);
actual_pressure=double(ep.getNodePressure);actual_pressure=actual_pressure(:);
actual_chlorine=double(ep.getNodeActualQuality);
actual_chlorine=actual_chlorine(:);
if strcmp(cfg.id,'anytown')
    flow_scale=6.30901964e-5; % GPM to m3/s
    pressure_scale=0.3048*cfg.pressure_to_head; % psi to m
elseif strcmp(cfg.id,'tanyimboh_templeman')
    flow_scale=1/3600; % m3/h to m3/s
    pressure_scale=1;
elseif strcmp(cfg.id,'balerma')
    flow_scale=0.001; % L/s to m3/s
    pressure_scale=1;
else
    error('Unknown EPANET outage flow units');
end
demand(found)=actual_demand(position(found))*flow_scale;
pressure(found)=actual_pressure(position(found))*pressure_scale;
chlorine(found)=actual_chlorine(position(found));
assert(all(isfinite(demand)) && all(isfinite(chlorine)) && ...
    all(isfinite(pressure(found))), 'Non-finite EPANET outage output');
end
