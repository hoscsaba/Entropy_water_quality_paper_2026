function [dda_pooled,pda_pooled] = run_anytown_physical_reservoir_outages( ...
        paper_root,staci_root,mex_dir,nominal_variant)
%RUN_ANYTOWN_PHYSICAL_RESERVOIR_OUTAGES Three source states x 38 pipe faults.
% Each of six saved designs from the selected nominal variant is evaluated
% with physical reservoirs in all 114 equally weighted cases. Neither source unavailability nor pipe failure
% triggers reoptimization. R10/pump 82 always remain available.

addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','anytown');
addpath(network_dir);
if nargin<4, nominal_variant="physical_reservoirs"; end
if string(nominal_variant)=="anchor_replay"
    cfg=network_config_anchor_replay(network_dir);
elseif string(nominal_variant)=="physical_reservoirs"
    cfg=network_config_physical_reservoirs(network_dir);
else
    error('Unknown nominal design variant: %s',nominal_variant);
end
source_cfg=network_config_physical_reservoirs(network_dir);
folder=cfg.results_dir;
cases_dir=fullfile(folder,'outage_scenarios');
if ~isfolder(cases_dir),mkdir(cases_dir);end
objectives=["cost","hydraulic_entropy", ...
    "branch_hop_weighted_entropy","chlorine_concentration", ...
    "chlorine_entropy","todini"];
labels=["Cost","Flow entropy","Branch-hop entropy", ...
    "Cl concentration","Cl entropy","Todini"];
availabilities={ ["65";"165"],"65","165" };
availability_names=["both","only_R65","only_R165"];
dda_files=strings(3,1);pda_files=strings(3,1);
for a=1:3
    dda_files(a)=fullfile(cases_dir,availability_names(a)+'_dda.inp');
    pda_files(a)=fullfile(cases_dir,availability_names(a)+'_pda.inp');
    wdn.write_anytown_physical_availability_input(source_cfg,source_cfg.inp_file, ...
        dda_files(a),availabilities{a},'dda');
    wdn.write_anytown_physical_availability_input(source_cfg,source_cfg.inp_file, ...
        pda_files(a),availabilities{a},'pda');
    expected_open=ismember(["65";"165"],availabilities{a});
    for path=[dda_files(a),pda_files(a)]
        model=StaciModel(path);
        release=onCleanup(@()model.release());
        actual_open=double(model.getLinkProperty(["78";"80"],'status'))>0;
        assert(isequal(actual_open(:),expected_open(:)), ...
            'Wrong reservoir connector availability');
        assert(model.getLinkProperty("82",'status')>0, ...
            'R10 pump is unavailable');
        state=model.solveHydraulics();
        assert(state.converged, ...
            'Unfailed physical-reservoir availability case did not converge');
        nodes=model.nodeResults();
        [found,positions]=ismember(["65";"165"],string(nodes.id(:)));
        assert(all(found),'Physical reservoir nodes are missing');
        reservoir_head_ft=double(nodes.total_head_m(positions))/0.3048;
        assert(all(abs(reservoir_head_ft(expected_open)-215)<1e-4), ...
            'Available physical reservoir head is not 215 ft');
        clear release model
    end
end

dda_pooled=table;pda_pooled=table;
dda_by_availability=table;pda_by_availability=table;
dda_all_cases=table;pda_all_cases=table;
for j=1:numel(objectives)
    saved=load(fullfile(folder,objectives(j)+'.mat'),'result');
    r=saved.result;
    assert(r.max_constraint_violation<=cfg.ga.constraint_tolerance, ...
        'Saved nominal design is infeasible');
    dda_rows=cell(3,1);pda_rows=cell(3,1);
    for a=1:3
        label=labels(j)+" / "+availability_names(a);
        [dda,dda_cases]=wdn.staci_pipe_failure_stress_test(cfg, ...
            r.design_diameters,label,cfg.inp_file,dda_files(a));
        [pda,pda_cases]=wdn.staci_pda_failure_service(cfg, ...
            r.design_diameters,label,dda_files(a),pda_files(a));
        dda_rows{a}=dda;pda_rows{a}=pda;
        dda_row=struct2table(dda);
        dda_row.Objective=objectives(j);
        dda_row.Availability=availability_names(a);
        pda.Objective=objectives(j);
        pda.Availability=availability_names(a);
        dda_cases.Objective=repmat(objectives(j),height(dda_cases),1);
        dda_cases.Availability=repmat(availability_names(a), ...
            height(dda_cases),1);
        pda_cases.Objective=repmat(objectives(j),height(pda_cases),1);
        pda_cases.Availability=repmat(availability_names(a), ...
            height(pda_cases),1);
        dda_by_availability=append_rows(dda_by_availability,dda_row);
        pda_by_availability=append_rows(pda_by_availability,pda);
        dda_all_cases=append_rows(dda_all_cases,dda_cases);
        pda_all_cases=append_rows(pda_all_cases,pda_cases);
    end
    pooled_dda=pool_dda(dda_rows,labels(j));
    pooled_pda=pool_pda(pda_rows,labels(j));
    pooled_dda.Objective=objectives(j);
    pooled_pda.Objective=objectives(j);
    dda_pooled=append_rows(dda_pooled,pooled_dda);
    pda_pooled=append_rows(pda_pooled,pooled_pda);
    fprintf(['%s: 114 faults, pressure %.3f%%, Cl %.3f%%, ' ...
        'mean delivery %.3f%%, worst delivery %.3f%%\n'], ...
        labels(j),100*pooled_dda.pressure_violation_fraction, ...
        100*pooled_dda.chlorine_violation_fraction, ...
        100*pooled_pda.MeanDeliveredDemandFraction, ...
        100*pooled_pda.WorstDeliveredDemandFraction);
end
dda_pooled=movevars(dda_pooled,'Objective','Before',1);
pda_pooled=movevars(pda_pooled,'Objective','Before',1);
dda_by_availability=movevars(dda_by_availability, ...
    {'Objective','Availability'},'Before',1);
pda_by_availability=movevars(pda_by_availability, ...
    {'Objective','Availability'},'Before',1);
writetable(dda_pooled,fullfile(folder,'stress_test_six_pooled.csv'));
writetable(pda_pooled,fullfile(folder,'pda_service_six_pooled.csv'));
writetable(dda_by_availability, ...
    fullfile(folder,'stress_test_six_by_availability.csv'));
writetable(pda_by_availability, ...
    fullfile(folder,'pda_service_six_by_availability.csv'));
writetable(dda_all_cases,fullfile(folder,'stress_test_all_scenarios.csv'));
writetable(pda_all_cases,fullfile(folder,'pda_service_all_scenarios.csv'));
end

function output=append_rows(output,more)
if isempty(output),output=more;else,output=[output;more];end
end

function pooled=pool_dda(rows,label)
n=cellfun(@(r)r.scenario_node_count,rows);
N=sum(n);
mu=cellfun(@(r)r.mean_chlorine_mg_L,rows);
sd=cellfun(@(r)r.std_chlorine_mg_L,rows);
pooled_mu=sum(n.*mu)/N;
pooled_sd=sqrt(sum((n-1).*sd.^2+n.*(mu-pooled_mu).^2)/(N-1));
pooled=struct2table(rows{1});
pooled.topology=label;
pooled.failed_pipe_count=sum(cellfun(@(r)r.failed_pipe_count,rows));
pooled.scenario_node_count=N;
pooled.pressure_violation_count= ...
    sum(cellfun(@(r)r.pressure_violation_count,rows));
pooled.pressure_violation_fraction=pooled.pressure_violation_count/N;
pooled.chlorine_violation_count= ...
    sum(cellfun(@(r)r.chlorine_violation_count,rows));
pooled.chlorine_violation_fraction=pooled.chlorine_violation_count/N;
pooled.mean_chlorine_mg_L=pooled_mu;
pooled.std_chlorine_mg_L=pooled_sd;
pooled.chlorine_cv_fraction=pooled_sd/pooled_mu;
pooled.nonconvergent_scenario_count= ...
    sum(cellfun(@(r)r.nonconvergent_scenario_count,rows));
pooled.minimum_pressure_psi=min(cellfun( ...
    @(r)r.minimum_pressure_psi,rows));
pooled.minimum_chlorine_mg_L=min(cellfun( ...
    @(r)r.minimum_chlorine_mg_L,rows));
end

function pooled=pool_pda(rows,label)
counts=cellfun(@(r)r.FailedPipeCount,rows);
assert(max(cellfun(@(r)r.RequestedDemand,rows))- ...
    min(cellfun(@(r)r.RequestedDemand,rows))<1e-10, ...
    'Requested demand differs between source states');
N=sum(counts);
pooled=rows{1};
pooled.Topology=label;
pooled.FailedPipeCount=N;
for field=["MeanDeliveredDemandFraction", ...
        "MeanQualityCompliantDemandFraction", ...
        "MeanPressureViolationFraction"]
    pooled.(field)=sum(counts.*cellfun(@(r)r.(field),rows))/N;
end
for field=["WorstDeliveredDemandFraction", ...
        "WorstQualityCompliantDemandFraction"]
    pooled.(field)=min(cellfun(@(r)r.(field),rows));
end
pooled.MaxOverdelivery=max(cellfun(@(r)r.MaxOverdelivery,rows));
pooled.NonconvergentScenarioCount= ...
    sum(cellfun(@(r)r.NonconvergentScenarioCount,rows));
end
