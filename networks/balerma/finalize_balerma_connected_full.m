function audit = finalize_balerma_connected_full( ...
        paper_root,staci_root,mex_dir,result_dir_override,cfg_override)
%FINALIZE_BALERMA_CONNECTED_FULL Audit fresh physical-reservoir designs.
% All four physical reservoirs retain their fixed heads and may supply or
% absorb water. No pressure anchor or zero-flow substitution is applied.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','balerma');
addpath(network_dir);
cfg=network_config(network_dir);
if nargin>=5 && ~isempty(cfg_override),cfg=cfg_override;end
if ismember('branch_hop_weighted_entropy',cfg.objectives) && ...
        ~isfield(cfg,'branch_hop_weighting')
    cfg.branch_hop_weighting=balerma_connected_branch_weights(cfg);
end
if nargin<4 || isempty(result_dir_override)
    cfg.results_dir=fullfile(network_dir,'results_staci_connected');
else
    cfg.results_dir=char(result_dir_override);
end
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
st=StaciModel(input_file);
cleanup=onCleanup(@()st.release());
design_ids=string(cfg.design_link_ids(:));
[link_order,full_original]=wdn.staci_input_link_template( ...
    input_file,st,0.001);
original=double(st.getLinkProperty(design_ids,'diameter_m'))/0.001;
[baseline.metrics,baseline.max_constraint_violation]= ...
    wdn.evaluate_staci_design(st,cfg,original,link_order,full_original);
baseline.network_id='balerma';
baseline.model='staci_steady_first_order';
baseline.full_link_ids=cellstr(link_order);
baseline.full_diameters=baseline.metrics.full_diameters;
baseline.design_diameters=original;
save(fullfile(cfg.results_dir,'baseline.mat'),'baseline','-v7');

reservoir_ids=string(cfg.source_node_ids(:));
assert(isequal(sort(reservoir_ids),sort(["38";"43";"44";"88"])), ...
    'All four Balerma sources are required');
names=string(cfg.objectives);
if ismember("branch_hop_weighted_entropy",names)
    names=["cost","hydraulic_entropy", ...
        "branch_hop_weighted_entropy","chlorine_concentration", ...
        "chlorine_entropy","todini"];
end
designs=["Original";names(:)];
raw=nan(numel(names),6);
rows=cell(numel(designs)*numel(reservoir_ids),5);
row=0;
for k=1:numel(designs)
    if k==1
        x=original;
    else
        saved=load(fullfile(cfg.results_dir,names(k-1)+'.mat'),'result');
        assert(isfield(saved.result,'connected_recalculation_id') || ...
            (isfield(saved.result,'constraint_set_id') && ...
            strcmp(saved.result.constraint_set_id,cfg.constraint_set_id)), ...
            'Fresh GA result missing: %s',names(k-1));
        x=saved.result.design_diameters;
    end
    [metrics,violation]=wdn.evaluate_staci_design( ...
        st,cfg,x,link_order,full_original);
    if k>1
        assert(violation<=cfg.ga.constraint_tolerance, ...
            'Balerma optimized design violates nominal constraints: %s',designs(k));
        if numel(names)==6
            raw(k-1,:)=[metrics.cost,metrics.hydraulic_entropy, ...
                metrics.branch_hop_weighted_entropy, ...
                metrics.chlorine_concentration,metrics.chlorine_entropy, ...
                metrics.todini];
        end
    end
    status=st.solveHydraulics();
    assert(status.converged,'Balerma design hydraulics failed: %s',designs(k));
    n=st.nodeResults(); e=st.linkResults();
    nodes=string(n.id(:));
    link_ids=string(e.id(:));
    from=string(e.from_node(:));
    q=double(e.flow_rate_m3s(:));
    net_source_outflow=0;
    for source=reservoir_ids'
        [found,index]=ismember(source,nodes);
        assert(found,'Physical reservoir missing: %s',source);
        head=double(n.total_head_m(index));
        boundary_id="EPANET_RESERVOIR_"+source;
        [boundary_found,boundary_index]=ismember(boundary_id,link_ids);
        assert(boundary_found && from(boundary_index)==source, ...
            'STACI physical reservoir boundary missing: %s',source);
        % STACI imports each EPANET reservoir as a boundary element. Its
        % positive link direction is from the network to the reservoir;
        % reverse that sign to report positive supply to the network.
        source_outflow=-q(boundary_index);
        net_source_outflow=net_source_outflow+source_outflow;
        row=row+1;
        rows(row,:)={designs(k),source,head,source_outflow,status.converged};
    end
    [junction_found,junction_index]=ismember( ...
        string(cfg.pressure_node_ids(:)),nodes);
    assert(all(junction_found),'Balerma demand node missing from source audit');
    requested=sum(double(n.demand_m3s(junction_index)));
    assert(abs(net_source_outflow-requested)<1e-7, ...
        'Reservoir supply does not balance junction demand: %s',designs(k));
end
audit=cell2table(rows,'VariableNames', ...
    {'Design','ReservoirID','TotalHead_m','SignedOutflow_m3s','Converged'});
head_targets=[117;127;122;112];
[~,ix]=ismember(string(audit.ReservoirID),["38";"43";"44";"88"]);
assert(all(abs(audit.TotalHead_m-head_targets(ix))<1e-6), ...
    'A physical reservoir head changed during nominal evaluation');
writetable(audit,fullfile(cfg.results_dir,'connected_reservoir_audit.csv'));
if numel(names)==6
    assert(all(isfinite(raw(:))),'Missing Balerma six-objective cross-evaluation');
    normalized=raw;
    normalized(:,1)=raw(:,1)/min(raw(:,1));
    for j=2:6,normalized(:,j)=raw(:,j)/max(raw(:,j));end
    vars={'Cost','FlowEntropy','BranchHopEntropy', ...
        'ChlorineConcentration','ChlorineEntropy','Todini'};
    labels=["Cost";"Flow entropy";"Branch-hop entropy"; ...
        "Cl concentration";"Cl entropy";"Todini"];
    raw_table=addvars(array2table(raw,'VariableNames',vars), ...
        labels,'Before',1,'NewVariableNames','OptimizedFor');
    norm_table=addvars(array2table(normalized,'VariableNames',vars), ...
        labels,'Before',1,'NewVariableNames','OptimizedFor');
    writetable(raw_table,fullfile(cfg.results_dir, ...
        'cross_evaluation_six_raw.csv'));
    writetable(norm_table,fullfile(cfg.results_dir, ...
        'cross_evaluation_six.csv'));
else
    wdn.write_cross_evaluation(cfg);
end
disp(audit);
end
