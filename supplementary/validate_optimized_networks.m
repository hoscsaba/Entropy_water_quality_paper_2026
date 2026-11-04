function [cross_engine, archive_replay] = validate_optimized_networks(repo_root, staci_root, mex_dir, output_dir)
%VALIDATE_OPTIMIZED_NETWORKS_20261104 Verify the paper's 21 final single-objective designs.
% Archive replay: saved EPANET state versus a fresh EPANET 48-h run.
% Cross-engine: STACI stationary state versus EPANET 14-day EPS on the
% same fixed-load INP and exact saved diameter vector.
if nargin < 1 || strlength(string(repo_root)) == 0
    repo_root = fileparts(fileparts(mfilename('fullpath')));
end
if nargin < 2 || strlength(string(staci_root)) == 0
    error('Pass the STACI checkout path.');
end
if nargin < 3 || strlength(string(mex_dir)) == 0
    error('Pass the STACI MEX build directory.');
end
if nargin < 4 || strlength(string(output_dir)) == 0
    output_dir = fullfile(repo_root,'supplementary','results','validation_21');
end
addpath(repo_root);
addpath(fullfile(staci_root,'matlab'));
addpath(mex_dir);
if ~isfolder(output_dir), mkdir(output_dir); end
network_names = ["tanyimboh_templeman","anytown","balerma"];
archive_rows = cell(15,10);
cross_rows = cell(21,14);
a_row=0;c_row=0;
for network=network_names
    net_dir=fullfile(repo_root,'networks',char(network));
    addpath(net_dir); clear network_config;
    cfg=network_config(net_dir);
    cfg.runtime_dir=fullfile(output_dir,'runtime',char(network));
    if ~isfolder(cfg.runtime_dir),mkdir(cfg.runtime_dir);end
    wdn.setup_toolkit(cfg);
    [arch_ep, model]=wdn.open_network(cfg);
    archive_cleanup=onCleanup(@() arch_ep.unload);
    for objective=string(cfg.objectives)
        saved=load(fullfile(cfg.results_dir,objective+'.mat'),'result');
        result=saved.result;
        replay=wdn.evaluate_design(arch_ep,result.design_diameters,cfg,model,true);
        [ac,ae]=wdn.pressure_constraints(result.design_diameters,arch_ep,cfg,model);
        violation=max([0;ac(:);abs(ae(:))]);
        [hfac,qfac]=unit_factors(network);
        if network=="anytown",pfac=0.3048*cfg.pressure_to_head;else,pfac=1;end
        dh=abs((double(replay.pressures(:))-double(result.metrics.pressures(:)))*pfac);
        dq=abs((double(replay.flows(:))-double(result.metrics.flows(:)))*qfac*1000);
        dc=abs(double(replay.chlorine(:))-double(result.metrics.chlorine(:)));
        assert(all(isfinite([dh;dq;dc])),'Non-finite archived replay difference');
        assert(violation<=cfg.ga.constraint_tolerance+1e-7,'Archive constraint violation');
        a_row=a_row+1;
        archive_rows(a_row,:)={network,objective,numel(dh),numel(dq), ...
            max(dh),mean(dh),max(dq),mean(dq),max(dc),mean(dc)};
        fprintf('ARCHIVE %-22s/%-23s H max %.3g m, Q max %.3g L/s, Cl max %.3g mg/L\n', ...
            network,objective,max(dh),max(dq),max(dc));
    end
    clear archive_cleanup arch_ep model;
    for objective=string(cfg.objectives)
        saved=load(fullfile(cfg.results_dir,objective+'.mat'),'result');
        [cross_rows,c_row]=cross_case(repo_root,output_dir,staci_root,mex_dir, ...
            network,objective,"archive",saved.result,cfg,cross_rows,c_row);
    end
    for objective=["chlorine_concentration","chlorine_entropy"]
        saved=load(fullfile(net_dir,'results_staci_constrained',objective+'.mat'),'result');
        [cross_rows,c_row]=cross_case(repo_root,output_dir,staci_root,mex_dir, ...
            network,objective,"staci_ga",saved.result,cfg,cross_rows,c_row);
    end
    rmpath(net_dir);
end
archive_replay=cell2table(archive_rows,'VariableNames', ...
    {'network','objective','node_count','link_count', ...
     'max_abs_pressure_head_m','mean_abs_pressure_head_m','max_abs_flow_Lps','mean_abs_flow_Lps', ...
     'max_abs_chlorine_mgL','mean_abs_chlorine_mgL'});
cross_engine=cell2table(cross_rows,'VariableNames', ...
    {'network','objective','design_source','node_count','link_count', ...
     'max_abs_head_m','mean_abs_head_m','max_abs_flow_Lps','mean_abs_flow_Lps', ...
     'max_abs_chlorine_mgL','mean_abs_chlorine_mgL', ...
     'max_anchor_head_deviation_ft','max_anchor_connector_flow_GPM', ...
     'minimum_epanet_consumer_chlorine_mgL'});
writetable(archive_replay,fullfile(output_dir,'archive_epanet_replay.csv'));
writetable(cross_engine,fullfile(output_dir,'staci_epanet_21_designs.csv'));
end

function [rows,index]=cross_case(repo_root,output_dir,staci_root,mex_dir, ...
    network,objective,design_source,result,cfg,rows,index)
if design_source=="archive"
    source=fullfile(repo_root,'supplementary','results',char(network),char(objective),'fixed_load.inp');
else
    source=fullfile(repo_root,'supplementary','results','staci_ga',char(network),char(objective),'fixed_load.inp');
end
assert(isfile(source),'Fixed-load verification INP missing: %s',source);
case_dir=fullfile(output_dir,'cases',char(network),char(objective),char(design_source));
if ~isfolder(case_dir),mkdir(case_dir);end
copyfile(source,fullfile(case_dir,'fixed_load.inp'),'f');
prior=pwd;cd(case_dir);dir_cleanup=onCleanup(@()cd(prior));
if isfield(cfg,'epanet_library') && strlength(string(cfg.epanet_library))>0
    ep=epanet('fixed_load.inp',cfg.epanet_library);
else
    ep=epanet('fixed_load.inp');
end
ep_cleanup=onCleanup(@()ep.unload);
st=StaciModel(fullfile(case_dir,'fixed_load.inp'));
st_cleanup=onCleanup(@()st.release());
design_ids=string(cfg.design_link_ids(:));
x=double(result.design_diameters(:));
ep_ids=string(ep.getLinkNameID);
[found,design_index]=ismember(design_ids,ep_ids);
assert(all(found) && numel(x)==numel(design_index),'Design link mismatch');
ep_diam=double(ep.getLinkDiameter);
ep_diam(design_index)=x;
ep.setLinkDiameter(ep_diam);
if network=="anytown",diameter_scale=0.0254;else,diameter_scale=0.001;end
st.setLinkProperty(design_ids,'diameter_m',x*diameter_scale);
ep.solveCompleteHydraulics;
ep_heads=double(ep.getNodeHydraulicHead);ep_heads=ep_heads(:);
ep_flows=double(ep.getLinkFlows);ep_flows=ep_flows(:);
ep.solveCompleteQuality;
ep_chlorine=double(ep.getNodeActualQuality);ep_chlorine=ep_chlorine(:);
status=st.solveHydraulics();assert(status.converged,'STACI hydraulics not converged');
snodes=st.nodeResults();slinks=st.linkResults();squality=st.solveSteadyQuality('chemical');
ep_nodes=string(ep.getNodeNameID);
[found_node,node_idx]=ismember(ep_nodes,string(snodes.id(:)));
[found_link,link_idx]=ismember(ep_ids,string(slinks.id(:)));
[found_cl,cl_idx]=ismember(ep_nodes,string(squality.node_ids(:)));
assert(all(found_node)&&all(found_link)&&all(found_cl),'EPANET/STACI ID mismatch');
[hfac,qfac]=unit_factors(network);
h=abs(ep_heads*hfac-double(snodes.total_head_m(node_idx)));
q=abs(ep_flows*qfac-double(slinks.flow_rate_m3s(link_idx)))*1000;
c=abs(ep_chlorine-1000*double(squality.node_concentration_kgm3(cl_idx)));
assert(all(isfinite([h;q;c])),'Non-finite EPANET/STACI difference');
anchor_deviation=NaN;connector_flow=NaN;
if network=="anytown"
    [found_anchor,ai]=ismember(string(cfg.pressure_anchor_node_ids),ep_nodes);
    [found_conn,li]=ismember(["78","80"],ep_ids);
    assert(all(found_anchor)&&all(found_conn),'Anytown anchor ID mismatch');
    anchor_deviation=max(abs(ep_heads(ai)-double(cfg.pressure_anchor_target_heads(:))));
    connector_flow=max(abs(ep_flows(li)));
    assert(anchor_deviation<=cfg.pressure_anchor_head_tolerance+0.01, ...
        'Anytown anchor target failed');
end
material_threshold=pi/4*0.010^2*0.01;
material_consumers=double(snodes.demand_m3s(node_idx))>material_threshold;
assert(any(material_consumers),'No material-demand consumer nodes');
min_consumer_cl=min(ep_chlorine(material_consumers));
index=index+1;
rows(index,:)={network,objective,design_source,numel(h),numel(q), ...
    max(h),mean(h),max(q),mean(q),max(c),mean(c), ...
    anchor_deviation,connector_flow,min_consumer_cl};
fprintf('CROSS   %-22s/%-23s %-8s H max %.3g m, Q max %.3g L/s, Cl max %.3g mg/L\n', ...
    network,objective,design_source,max(h),max(q),max(c));
clear st_cleanup ep_cleanup dir_cleanup st ep;
end

function [head_to_m,flow_to_m3s]=unit_factors(network)
if network=="anytown"
    head_to_m=0.3048;flow_to_m3s=6.30901964e-5;
elseif network=="tanyimboh_templeman"
    head_to_m=1;flow_to_m3s=1/3600;
else
    head_to_m=1;flow_to_m3s=0.001;
end
end
