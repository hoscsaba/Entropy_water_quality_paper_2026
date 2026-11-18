function [pda_pooled,pda_by_availability,pda_all_cases] = run_anytown_physical_reservoir_outages( ...
        paper_root,staci_root,mex_dir,nominal_variant,result_dir_override)
%RUN_ANYTOWN_PHYSICAL_RESERVOIR_OUTAGES PDA-only pipe-outage service replay.
% Three source states (both tanks, R65 alone, R165 alone) are each paired
% with closure of every physical pipe. Nominal diameters remain fixed.
% Fixed-load input files supply the requested-demand denominator; they are
% imported without any DDA hydraulic solve. Every hydraulic solve here is PDA.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','anytown');
addpath(network_dir);
if nargin<4, nominal_variant="anchor_replay"; end
if nargin<5,result_dir_override=[];end
if string(nominal_variant)=="anchor_replay"
    cfg=network_config_anchor_replay(network_dir);
elseif string(nominal_variant)=="physical_reservoirs"
    cfg=network_config_physical_reservoirs(network_dir);
else
    error('Unknown nominal design variant: %s',nominal_variant);
end
if ~isempty(result_dir_override),cfg.results_dir=char(result_dir_override);end
source_cfg=network_config_physical_reservoirs(network_dir);
folder=cfg.results_dir;
cases_dir=fullfile(folder,'outage_scenarios');
if ~isfolder(cases_dir),mkdir(cases_dir);end
objectives=["cost","hydraulic_entropy","branch_hop_weighted_entropy", ...
    "chlorine_concentration","chlorine_entropy","todini"];
labels=["Cost","Flow entropy","Branch-hop entropy", ...
    "Cl concentration","Cl entropy","Todini"];
availabilities={ ["65";"165"],"65","165" };
availability_names=["both","only_R65","only_R165"];
base_files=strings(3,1);pda_files=strings(3,1);
for a=1:3
    base_files(a)=fullfile(cases_dir,availability_names(a)+'_fixed_load.inp');
    pda_files(a)=fullfile(cases_dir,availability_names(a)+'_pda.inp');
    wdn.write_anytown_physical_availability_input(source_cfg,source_cfg.inp_file, ...
        base_files(a),availabilities{a},'dda');
    wdn.write_anytown_physical_availability_input(source_cfg,source_cfg.inp_file, ...
        pda_files(a),availabilities{a},'pda');
    model=StaciModel(pda_files(a));
    release=onCleanup(@()model.release());
    expected_open=ismember(["65";"165"],availabilities{a});
    actual_open=double(model.getLinkProperty(["78";"80"],'status'))>0;
    assert(isequal(actual_open(:),expected_open(:)), ...
        'Wrong reservoir connector availability');
    assert(model.getLinkProperty("82",'status')>0, ...
        'R10 pump is unavailable');
    state=model.solveHydraulics();
    assert(state.converged,'Intact PDA source state did not converge');
    nodes=model.nodeResults();
    [found,positions]=ismember(["65";"165"],string(nodes.id(:)));
    assert(all(found),'Physical reservoir nodes are missing');
    reservoir_head_ft=double(nodes.total_head_m(positions))/0.3048;
    assert(all(abs(reservoir_head_ft(expected_open)-215)<1e-4), ...
        'Available physical reservoir head is not 215 ft');
    clear release model
end
pda_pooled=table;pda_by_availability=table;pda_all_cases=table;
for j=1:numel(objectives)
    saved=load(fullfile(folder,objectives(j)+'.mat'),'result');
    r=saved.result;
    assert(r.max_constraint_violation<=cfg.ga.constraint_tolerance, ...
        'Saved nominal design is infeasible');
    rows=cell(3,1);
    for a=1:3
        label=labels(j)+" / "+availability_names(a);
        [row,cases]=wdn.staci_pda_failure_service(cfg, ...
            r.design_diameters,label,base_files(a),pda_files(a));
        row.Objective=objectives(j);
        row.Availability=availability_names(a);
        cases.Objective=repmat(objectives(j),height(cases),1);
        cases.Availability=repmat(availability_names(a),height(cases),1);
        rows{a}=row;
        pda_by_availability=append_rows(pda_by_availability,row);
        pda_all_cases=append_rows(pda_all_cases,cases);
    end
    pooled=pool_pda(rows,labels(j));
    pooled.Objective=objectives(j);
    pda_pooled=append_rows(pda_pooled,pooled);
end
pda_pooled=movevars(pda_pooled,'Objective','Before',1);
pda_by_availability=movevars(pda_by_availability, ...
    {'Objective','Availability'},'Before',1);
pda_all_cases=movevars(pda_all_cases, ...
    {'Objective','Availability'},'Before',1);
writetable(pda_pooled,fullfile(folder,'pda_service_six_pooled.csv'));
writetable(pda_by_availability, ...
    fullfile(folder,'pda_service_six_by_availability.csv'));
writetable(pda_all_cases,fullfile(folder,'pda_service_all_scenarios.csv'));
end

function output=append_rows(output,more)
if isempty(output),output=more;else,output=[output;more];end
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
