function result_dir=run_balerma_r38_anchor( ...
        paper_root,staci_root,mex_dir,stage)
%RUN_BALERMA_R38_ANCHOR Recalculate the six nominal designs and PDA replay.
% Stages: seed, full, audit_available, audit, validate, replay_available,
% replay, topology, rankings.
% R38 is a zero-flow 117 m pressure
% anchor in nominal optimization; R43/R44/R88 are physical reservoirs.
% Replay restores the untouched four-reservoir INP and closes each of the
% 448 nonconnector pipes once. Checkpoints permit interrupted runs to resume.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2 || isempty(staci_root)
    staci_root='/Users/hoscsaba/Documents/GitHub/staci';
end
if nargin<3 || isempty(mex_dir)
    mex_dir=fullfile(staci_root,'build-matlab','Matlab');
end
if nargin<4 || isempty(stage),stage="seed";end
stage=string(stage);
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
result_dir=cfg.results_dir;
if ~isfolder(result_dir),mkdir(result_dir);end
input_file=cfg.inp_file;
names=string(cfg.objectives);
if startsWith(stage,"full_")
    selected=extractAfter(stage,strlength("full_"));
    assert(ismember(selected,names), ...
        'Unknown independently requested Balerma objective: %s',selected);
    names=selected;
    stage="full";
elseif startsWith(stage,"replay_") && stage~="replay_available"
    selected=extractAfter(stage,strlength("replay_"));
    assert(ismember(selected,names), ...
        'Unknown independently requested Balerma replay: %s',selected);
    names=selected;
    stage="replay";
elseif startsWith(stage,"rankings_")
    selected=extractAfter(stage,strlength("rankings_"));
    assert(ismember(selected,names), ...
        'Unknown Balerma ranking objective: %s',selected);
    names=selected;
    stage="rankings";
end
seed_file=fullfile(result_dir,'feasible_seed.mat');
switch stage
    case "seed"
        [x,metrics,violation]=find_feasible_seed(cfg,input_file);
        assert(violation<=cfg.ga.constraint_tolerance, ...
            'R38-anchor starting design is not feasible');
        save(seed_file,'x','metrics','violation','-v7');
        fprintf('R38 seed: anchor %.6f m, chlorine %.6f mg/L, violation %.4g\n', ...
            anchor_head(metrics),metrics.minimum_consumer_chlorine_mgL, ...
            violation);
    case "full"
        if ~isfile(seed_file)
            run_balerma_r38_anchor(paper_root,staci_root,mex_dir,"seed");
        end
        saved=load(seed_file,'x');
        seed=double(saved.x(:)');
        for k=1:numel(names)
            name=names(k);
            target=fullfile(result_dir,name+".mat");
            if isfile(target)
                prior=load(target,'result');
                assert(strcmp(prior.result.constraint_set_id, ...
                    cfg.constraint_set_id) && ...
                    isequal(string(prior.result.design_link_ids(:)), ...
                    string(cfg.design_link_ids(:))), ...
                    'Incompatible R38-anchor checkpoint: %s',target);
                fprintf('SKIP %s: checked R38-anchor checkpoint exists\n',name);
                continue
            end
            cfg.ga.seed_designs.(char(name))=seed;
            % Keep several starts around the validated feasible design;
            % the shared GA still rechecks every candidate in memory.
            rng(cfg.ga.random_seed+k,'twister');
            perturbed=seed.*(1+0.025*randn(18,numel(seed)));
            cfg.ga.additional_seed_designs=min(max(perturbed, ...
                cfg.minimum_diameter),cfg.maximum_diameter);
            fprintf('START Balerma R38-anchor %s\n',name);
            result=wdn.optimize_staci_single_objective( ...
                cfg,char(name),input_file,target);
            result.nominal_pressure_anchor_node_ids={'38'};
            result.nominal_physical_reservoir_node_ids={'43','44','88'};
            result.physical_replay_reservoir_node_ids={'38','43','44','88'};
            save(target,'result','-v7');
            fprintf('DONE %s: generation %d, %.1f s, violation %.4g\n', ...
                name,result.ga_last_generation,result.elapsed_time_seconds, ...
                result.max_constraint_violation);
            seed=double(result.design_diameters(:)');
        end
    case "audit"
        audit_nominal(cfg,input_file,names,result_dir);
    case "audit_available"
        present=arrayfun(@(name)isfile(fullfile(result_dir,name+".mat")), ...
            names);
        assert(any(present),'No completed R38-anchor nominal design');
        audit_nominal(cfg,input_file,names(present),result_dir);
    case "validate"
        addpath(fullfile(paper_root,'supplementary'));
        validation_dir=fullfile(result_dir,'epanet_validation');
        validate_staci_final_designs(staci_root,mex_dir,validation_dir, ...
            'balerma',names,'r38_anchor',result_dir);
    case "replay"
        replay_four_reservoirs(cfg,network_dir,names,result_dir);
    case "replay_available"
        present=arrayfun(@(name)isfile(fullfile(result_dir,name+".mat")), ...
            names);
        assert(any(present),'No completed R38-anchor nominal design');
        replay_four_reservoirs(cfg,network_dir,names(present),result_dir);
    case "topology"
        rank_balerma_topological_pipe_outages(paper_root, ...
            fullfile(result_dir,'topological_outage_audit'));
    case "rankings"
        figure_dir=fullfile(network_dir,'figures_staci_r38_anchor_v1');
        run_staci_ranking_studies(staci_root,mex_dir,'balerma', ...
            names,result_dir,figure_dir,cfg);
    otherwise
        error('Unknown Balerma R38-anchor stage: %s',stage);
end
end

function [x,metrics,violation]=find_feasible_seed(cfg,input_file)
% Bisection on a broad, constant-diameter design; R88 connector P51 is
% held at 400 mm. This is a feasibility seed, not an optimized result.
st=StaciModel(input_file);
release=onCleanup(@()st.release()); %#ok<NASGU>
ids=string(cfg.design_link_ids(:));
[links,original]=wdn.staci_input_link_template(input_file,st,0.001);
lo=500;hi=600;
for k=1:22
    diameter=(lo+hi)/2;
    x=diameter*ones(numel(ids),1);
    x(ids=="51")=400;
    st.setLinkProperty(ids,'diameter_m',x*0.001);
    status=st.solveHydraulics();
    assert(status.converged,'R38 seed hydraulic solve failed');
    n=st.nodeResults();
    [found,i]=ismember("38",string(n.id(:)));
    assert(found);
    if double(n.total_head_m(i))<117,lo=diameter;
    else,hi=diameter;end
end
[metrics,violation]=wdn.evaluate_staci_design( ...
    st,cfg,x,links,original);
end

function value=anchor_head(metrics)
[found,i]=ismember("38",string(metrics.node_ids(:)));
assert(found);
value=metrics.heads_m(i);
end

function audit_nominal(cfg,input_file,names,result_dir)
st=StaciModel(input_file);
release=onCleanup(@()st.release()); %#ok<NASGU>
[links,original]=wdn.staci_input_link_template(input_file,st,0.001);
rows=cell(numel(names),1);
cross=zeros(numel(names),6);
vectors=zeros(numel(cfg.design_link_ids),numel(names));
for k=1:numel(names)
    saved=load(fullfile(result_dir,names(k)+".mat"),'result');
    assert(strcmp(saved.result.constraint_set_id,cfg.constraint_set_id));
    vectors(:,k)=double(saved.result.design_diameters(:));
    [m,v]=wdn.evaluate_staci_design(st,cfg, ...
        saved.result.design_diameters,links,original);
    cross(k,:)=[m.cost,m.hydraulic_entropy, ...
        m.branch_hop_weighted_entropy,m.chlorine_concentration, ...
        m.chlorine_entropy,m.todini];
    assert(v<=cfg.ga.constraint_tolerance, ...
        'Nominal R38-anchor design violates constraints: %s',names(k));
    n=st.nodeResults();e=st.linkResults();
    ni=string(n.id(:));ei=string(e.id(:));
    [~,i38]=ismember("38",ni);
    assert(abs(double(n.demand_m3s(i38)))<1e-12, ...
        'R38 is not a zero-flow pressure anchor');
    [found_connectors,ci]=ismember(["5","338"],ei);
    assert(all(found_connectors) && ...
        all(string(e.to_node(ci))=="38"), ...
        'R38 connector orientation changed');
    connector_balance=sum(double(e.flow_rate_m3s(ci)));
    assert(abs(connector_balance)<1e-8, ...
        'R38 connector flow is not zero net');
    [found_assessed,assessed]=ismember( ...
        string(cfg.pressure_node_ids(:)),ni);
    assert(all(found_assessed));
    assessed_pressure=double(n.pressure_head_m(assessed));
    source_ids=["43","44","88"];
    q=zeros(3,1);
    for j=1:3
        [found,li]=ismember("EPANET_RESERVOIR_"+source_ids(j),ei);
        assert(found);
        q(j)=-double(e.flow_rate_m3s(li));
    end
    requested=sum(max(double(n.demand_m3s(assessed)),0));
    assert(abs(sum(q)-requested)<1e-7, ...
        'Physical reservoir supply does not balance demand');
    rows{k}=table(names(k),anchor_head(m), ...
        double(n.demand_m3s(i38)),connector_balance, ...
        q(1),q(2),q(3), ...
        min(assessed_pressure),max(assessed_pressure), ...
        m.minimum_consumer_chlorine_mgL,v, ...
        'VariableNames',{'Objective','R38Head_m','R38ExternalFlow_m3s', ...
        'R38ConnectorBalance_m3s', ...
        'R43Supply_m3s','R44Supply_m3s','R88Supply_m3s', ...
        'MinimumPressure_m','MaximumPressure_m', ...
        'MinimumConsumerChlorine_mgL','MaxConstraintViolation'});
end
audit=vertcat(rows{:});
writetable(audit,fullfile(result_dir,'nominal_anchor_audit.csv'));
columns={'Cost','HydraulicEntropy','BranchHopEntropy', ...
    'ChlorineConcentration','ChlorineEntropy','Todini'};
cross_table=addvars(array2table(cross,'VariableNames',columns), ...
    names(:),'Before',1,'NewVariableNames','OptimizedFor');
writetable(cross_table,fullfile(result_dir,'cross_evaluation_six_raw.csv'));
relative=cross;
relative(:,1)=cross(:,1)/min(cross(:,1));
for j=2:6,relative(:,j)=cross(:,j)/max(cross(:,j));end
relative_table=addvars(array2table(relative, ...
    'VariableNames',columns),names(:),'Before',1, ...
    'NewVariableNames','OptimizedFor');
writetable(relative_table,fullfile(result_dir, ...
    'cross_evaluation_six_relative_to_best.csv'));
diameters=table("P"+string(cfg.design_link_ids(:)), ...
    'VariableNames',{'PipeID'});
for j=1:numel(names)
    key=matlab.lang.makeValidName(char(names(j)));
    diameters.(key)=vectors(:,j);
end
writetable(diameters,fullfile(result_dir, ...
    'optimal_pipe_diameters_six_mm.csv'));
for j=1:numel(names)
    key=matlab.lang.makeValidName(char(names(j)));
    diameters.(key)=vectors(:,j)/25.4;
end
writetable(diameters,fullfile(result_dir, ...
    'optimal_pipe_diameters_six_in.csv'));
disp(audit);
end

function replay_four_reservoirs(cfg,network_dir,names,result_dir)
physical=fullfile(network_dir,'input','network_staci_fixed_load.inp');
assert(~strcmp(cfg.inp_file,physical), ...
    'Failure replay must restore the physical R38 reservoir');
pda_file=fullfile(result_dir,'runtime','physical_four_reservoir_pda.inp');
wdn.write_staci_pda_input(cfg,physical,pda_file);
base=StaciModel(physical);
requested=max(double(base.getNodeProperty( ...
    string(cfg.stress.node_ids(:)),'demand_m3s')),0);
requested=requested(:);
base.release();
assert(sum(requested)>0,'No Balerma consumer demand');
eligible=string(cfg.stress.failed_link_ids(:));
protected=string(cfg.stress.protected_link_ids(:));
assert(numel(eligible)==448 && isempty(intersect(eligible,protected)));
all_rows=cell(numel(names),1);
all_cases=cell(numel(names),1);
for k=1:numel(names)
    name=names(k);
    saved=load(fullfile(result_dir,name+".mat"),'result');
    assert(strcmp(saved.result.constraint_set_id,cfg.constraint_set_id));
    x=double(saved.result.design_diameters(:));
    cache=fullfile(result_dir,'pda_replay_cache','all_four_protected', ...
        name+".mat");
    if isfile(cache)
        old=load(cache,'cases','design_diameters');
        assert(isequal(old.design_diameters,x), ...
            'PDA checkpoint has another diameter vector');
        cases=old.cases;
    else
        tic;
        evalc('[~,cases]=wdn.staci_pda_failure_service(cfg,x,name,physical,pda_file);');
        cases.EpanetFallback=false(height(cases),1);
        for j=find(cases.Nonconvergent(:))'
            try
                [delivered,pressure,chlorine]= ...
                    wdn.epanet_connected_outage_outputs( ...
                    cfg,x,pda_file,cases.FailedLinkID(j), ...
                    cfg.stress.node_ids);
                delivered=min(max(delivered(:),0),requested);
                cases.DeliveredDemandFraction(j)= ...
                    sum(delivered)/sum(requested);
                cases.QualityCompliantDemandFraction(j)= ...
                    sum(delivered.*(chlorine(:)>=0.2))/sum(requested);
                cases.PressureViolationFraction(j)= ...
                    mean(pressure(:)<cfg.minimum_pressure | ...
                    pressure(:)>cfg.maximum_pressure);
                cases.Nonconvergent(j)=false;
                cases.EpanetFallback(j)=true;
                cases.ErrorMessage(j)= ...
                    "STACI nonconverged; EPANET PDA/EPS rescue";
            catch exception
                cases.ErrorMessage(j)= ...
                    "STACI and EPANET failed: "+string(exception.message);
            end
        end
        assert(all(~cases.Nonconvergent), ...
            'Incomplete PDA replay for %s',name);
        folder=fileparts(cache);
        if ~isfolder(folder),mkdir(folder);end
        design_diameters=x; %#ok<NASGU>
        save(cache,'cases','design_diameters','-v7');
        fprintf('PDA %s: %d cases in %.1f min\n', ...
            name,height(cases),toc/60);
    end
    assert(height(cases)==448 && ...
        isequal(sort(string(cases.FailedLinkID)),sort(eligible)) && ...
        all(~cases.Nonconvergent), ...
        'Incomplete or incompatible protected replay for %s',name);
    water=double(cases.DeliveredDemandFraction);
    chlorine=double(cases.QualityCompliantDemandFraction);
    n10=ceil(0.1*numel(water));
    all_rows{k}=table(name,448,100*mean(water),100*min(water), ...
        100*mean(mink(water,n10)),100*mean(chlorine), ...
        100*min(chlorine), ...
        'VariableNames',{'Objective','FailureCases', ...
        'MeanWaterPct','WorstWaterPct','WorstTenPercentWaterPct', ...
        'MeanChlorineCompliantPct','WorstChlorineCompliantPct'});
    cases.Objective=repmat(name,height(cases),1);
    all_cases{k}=cases;
end
writetable(vertcat(all_rows{:}), ...
    fullfile(result_dir,'pda_four_reservoir_protected_summary.csv'));
writetable(vertcat(all_cases{:}), ...
    fullfile(result_dir,'pda_four_reservoir_protected_cases.csv'));
end
