function [summary,scenarios] = run_tanyimboh_failure_service(paper_root,staci_root,mex_dir,results_dir)
%RUN_TANYIMBOH_FAILURE_SERVICE PDA-only N-1 replay of six saved designs.
% The 50-m reservoir at node 1 and the fixed node-2 injection remain
% available. Only P1--P8 are failed, one at a time.
% Requested demands are read from the fixed-load INP before solving PDA;
% no intact or failed demand-driven hydraulic run is required.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','tanyimboh_templeman');
addpath(network_dir);
cfg=network_config(network_dir);
if nargin>=4 && ~isempty(results_dir)
    cfg.results_dir=char(results_dir);
end
cfg.stress.allow_pda_tolerance_fallback=true;
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
pda_file=fullfile(cfg.results_dir,'runtime','network_pda_fixed_load.inp');
wdn.write_staci_pda_input(cfg,input_file,pda_file);
base=StaciModel(input_file);
requested=max(double(base.getNodeProperty( ...
    string(cfg.stress.node_ids(:)),'demand_m3s')),0);
requested=requested(:);
base.release();
objectives=["cost","hydraulic_entropy","branch_hop_weighted_entropy", ...
    "chlorine_concentration","chlorine_entropy","todini"];
labels=["Cost","Flow entropy","Branch-hop entropy", ...
    "Cl concentration","Cl entropy","Todini"];
summary=table();scenarios=table();
for j=1:numel(objectives)
    saved=load(fullfile(cfg.results_dir,objectives(j)+".mat"),'result');
    assert(strcmp(saved.result.constraint_set_id, ...
        'pressure_10_120m_chlorine_mass_split_v2'), ...
        'Saved design belongs to another constraint set');
    [row,cases]=wdn.staci_pda_failure_service(cfg, ...
        saved.result.design_diameters,labels(j),input_file,pda_file);
    cases.EpanetFallback=false(height(cases),1);
    for failed_index=find(cases.Nonconvergent(:))'
        % The tiny residual pipes in a cost design can defeat STACI's PDA
        % Newton solve even after its tolerance retry. EPANET is an
        % independent rescue on the same retained fixed-head component.
        try
            [delivered,pressure,concentration]= ...
                wdn.epanet_connected_outage_outputs(cfg, ...
                saved.result.design_diameters,pda_file, ...
                cases.FailedLinkID(failed_index),cfg.stress.node_ids);
            delivered=min(max(delivered(:),0),requested);
            cases.DeliveredDemandFraction(failed_index)= ...
                sum(delivered)/sum(requested);
            cases.QualityCompliantDemandFraction(failed_index)= ...
                sum(delivered.*(concentration(:)>= ...
                cfg.stress.minimum_chlorine))/sum(requested);
            cases.PressureViolationFraction(failed_index)= ...
                mean(pressure(:)<cfg.minimum_pressure | ...
                pressure(:)>cfg.maximum_pressure);
            cases.Nonconvergent(failed_index)=false;
            cases.EpanetFallback(failed_index)=true;
            cases.ErrorMessage(failed_index)= ...
                "STACI nonconverged; EPANET 2.2 PDA/EPS rescue";
        catch exception
            cases.ErrorMessage(failed_index)= ...
                "STACI and EPANET failed: " + string(exception.message);
        end
    end
    row.NonconvergentScenarioCount=nnz(cases.Nonconvergent);
    if row.NonconvergentScenarioCount==0
        row.MeanDeliveredDemandFraction=mean(cases.DeliveredDemandFraction);
        row.WorstDeliveredDemandFraction=min(cases.DeliveredDemandFraction);
        row.MeanQualityCompliantDemandFraction= ...
            mean(cases.QualityCompliantDemandFraction);
        row.WorstQualityCompliantDemandFraction= ...
            min(cases.QualityCompliantDemandFraction);
        row.MeanPressureViolationFraction=mean(cases.PressureViolationFraction);
    end
    if row.NonconvergentScenarioCount>0
        % A fixed-flow inlet on an island without a fixed-head reference
        % does not determine pressure-driven service. Failed solves must not
        % be averaged as zero delivery or reported as a valid worst case.
        unresolved=logical(cases.Nonconvergent);
        cases.DeliveredDemandFraction(unresolved)=NaN;
        cases.QualityCompliantDemandFraction(unresolved)=NaN;
        cases.PressureViolationFraction(unresolved)=NaN;
        row.MeanDeliveredDemandFraction=NaN;
        row.WorstDeliveredDemandFraction=NaN;
        row.MeanQualityCompliantDemandFraction=NaN;
        row.WorstQualityCompliantDemandFraction=NaN;
        row.MeanPressureViolationFraction=NaN;
    end
    row.Objective=objectives(j);
    cases.Objective=repmat(objectives(j),height(cases),1);
    summary=[summary;row]; %#ok<AGROW>
    scenarios=[scenarios;cases]; %#ok<AGROW>
end
summary=movevars(summary,'Objective','Before',1);
scenarios=movevars(scenarios,'Objective','Before',1);
writetable(summary,fullfile(cfg.results_dir,'pda_service_six.csv'));
writetable(scenarios,fullfile(cfg.results_dir,'pda_service_scenarios.csv'));
save(fullfile(cfg.results_dir,'pda_service_results.mat'), ...
    'summary','scenarios','cfg','-v7');
end
