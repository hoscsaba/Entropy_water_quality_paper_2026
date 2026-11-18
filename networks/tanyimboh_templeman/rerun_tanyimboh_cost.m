function result = rerun_tanyimboh_cost(staci_root, mex_dir, results_dir)
%RERUN_TANYIMBOH_COST Refit only the TT cost design under paper constraints.
% The original penalty GA retained a feasible chlorine-design warm start
% when its own best point was infeasible. This small eight-pipe benchmark
% permits a deterministic support scan: every connected five-edge subset
% is locally sized with log-diameter SQP from four starts. A fifth active
% edge may shrink to Dmin, giving a source-fed forest. The best feasible
% scan result seeds the same resident-STACI GA used by the paper.
%
% The selected lower-cost design is independently checked with EPANET 2.2
% before replacing cost.mat. The scan uses a 0.02 m inner pressure margin
% to cover solver differences; the published constraints remain 10--120 m
% and >=0.2 mg/L consumer chlorine. No other objective is optimized here.

root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
nd=fullfile(root,'networks','tanyimboh_templeman');
addpath(root,nd,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config(nd);
if nargin>=3 && ~isempty(results_dir)
    cfg.results_dir=char(results_dir);
end
ids=string(cfg.design_link_ids(:));
assert(isequal(ids,["P1";"P4";"P7";"P6";"P2";"P3";"P8";"P5"]), ...
    'Review TT support edges after changing the design-link order');
endpoints=[1 3;2 4;4 6;3 5;1 4;2 3;5 6;3 4];
pressure_guard_m=0.02;
starts_mm=[40,60,100,200];
st=StaciModel(cfg.inp_file);
release=onCleanup(@()st.release());
lengths=double(st.getLinkProperty(ids,'length_m'))';
initial=st.solveHydraulics();
assert(initial.converged,'TT initial hydraulics failed');
initial_nodes=st.nodeResults();
[found,pidx]=ismember(string(cfg.pressure_node_ids(:)), ...
    string(initial_nodes.id(:)));
assert(all(found),'TT pressure nodes not found');
options=optimoptions('fmincon','Algorithm','sqp','Display','off', ...
    'MaxIterations',200,'MaxFunctionEvaluations',3000, ...
    'ConstraintTolerance',1e-6,'OptimalityTolerance',1e-6, ...
    'StepTolerance',1e-9,'FiniteDifferenceType','central', ...
    'UseParallel',false);
sets=nchoosek(1:8,5);
connected_count=0;feasible_count=0;
best_cost=inf;best_x=[];best_active=[];
scan_started=tic;
for row=1:size(sets,1)
    active=sets(row,:);
    network=graph(endpoints(active,1),endpoints(active,2),[],6);
    if max(conncomp(network))~=1,continue;end
    connected_count=connected_count+1;
    local_cost=inf;
    for d0=starts_mm
        y=fmincon(@cost,log(d0)*ones(1,5),[],[],[],[], ...
            log(cfg.minimum_diameter)*ones(1,5), ...
            log(cfg.maximum_diameter)*ones(1,5), ...
            @constraints,options);
        c=cost(y)*1e5;
        violation=max([0;constraints(y)]);
        if violation<=cfg.ga.constraint_tolerance && c<local_cost
            local_cost=c;
            local_x=full_diameters(y);
        end
    end
    if isfinite(local_cost)
        feasible_count=feasible_count+1;
        if local_cost<best_cost
            best_cost=local_cost;
            best_x=local_x;
            best_active=active;
        end
    end
end
assert(~isempty(best_x),'TT support scan found no feasible seed');
scan_seconds=toc(scan_started);
fprintf('TT cost support scan: %d connected sets, %d feasible; best %.9g in %.2f s\n', ...
    connected_count,feasible_count,best_cost,scan_seconds);
clear release st

% The GA is still run with its released settings. A feasible support-scan
% vector is included in its initial population and final incumbent check.
cfg.ga.additional_seed_designs=best_x;
cfg.ga.random_seed=20261114;
cfg.ga.maximum_wall_seconds=1200;
ga_result=wdn.optimize_staci_single_objective(cfg,'cost',cfg.inp_file,'');
fresh=StaciModel(cfg.inp_file);
fresh_release=onCleanup(@()fresh.release());
[link_order,original]=wdn.staci_input_link_template( ...
    cfg.inp_file,fresh,0.001);
[scan_metrics,scan_violation]=wdn.evaluate_staci_design( ...
    fresh,cfg,best_x,link_order,original);
[ga_metrics,ga_violation]=wdn.evaluate_staci_design( ...
    fresh,cfg,ga_result.design_diameters,link_order,original);
assert(scan_violation<=cfg.ga.constraint_tolerance, ...
    'The support-scan seed fails the paper constraints');
if ga_violation<=cfg.ga.constraint_tolerance && ...
        ga_metrics.cost<scan_metrics.cost
    selected_x=double(ga_result.design_diameters(:)');
    selected_metrics=ga_metrics;
    selected_violation=ga_violation;
    selection='GA';
else
    selected_x=best_x;
    selected_metrics=scan_metrics;
    selected_violation=scan_violation;
    selection='support scan + log-SQP';
end

% EPANET is an independent acceptance check, not an optimization engine.
epcheck=check_epanet(cfg,selected_x,selected_metrics);
assert(epcheck.minimum_pressure_m>=cfg.minimum_pressure-1e-6 && ...
    epcheck.maximum_pressure_m<=cfg.maximum_pressure+1e-6 && ...
    epcheck.minimum_consumer_chlorine_mgL>=0.2-1e-6, ...
    'Independent EPANET replay rejects the selected TT cost design');
result=ga_result;
result.design_diameters=selected_x;
result.metrics=selected_metrics;
result.max_constraint_violation=selected_violation;
result.optimizer_value=selected_metrics.cost;
result.incumbent_source=selection;
result.optimizer='MATLAB GA with TT support scan and log-SQP refinement';
result.cost_refinement=struct( ...
    'connected_supports',connected_count, ...
    'feasible_supports',feasible_count, ...
    'starts_mm',starts_mm, ...
    'pressure_seed_guard_m',pressure_guard_m, ...
    'best_support_link_ids',{cellstr(ids(best_active))}, ...
    'support_scan_seconds',scan_seconds, ...
    'ga_exitflag',ga_result.exitflag, ...
    'selected_method',selection);
result.epanet_replay=epcheck;
[found,position]=ismember(ids,link_order);
assert(all(found));
result.full_diameters=double(original(:)');
result.full_diameters(position)=selected_x;
result.metrics.full_diameters=result.full_diameters;
result.created_at=datetime('now','TimeZone','local');
target=fullfile(cfg.results_dir,'cost.mat');
save(target,'result','-v7');
fprintf('TT cost saved: %.9g, STACI violation %.3g, EPANET pressure %.5f--%.5f m, source %s\n', ...
    result.metrics.cost,result.max_constraint_violation, ...
    epcheck.minimum_pressure_m,epcheck.maximum_pressure_m,selection);

    function x=full_diameters(y)
        x=cfg.minimum_diameter*ones(1,8);
        x(active)=exp(y(:));
    end
    function f=cost(y)
        f=wdn.pipe_cost(full_diameters(y),lengths,cfg)/1e5;
    end
    function [c,ceq]=constraints(y)
        ceq=[];
        try
            st.setLinkProperty(ids,'diameter_m', ...
                full_diameters(y)'*0.001);
            status=st.solveHydraulics();
            if ~status.converged
                c=1e3*ones(numel(pidx)*2+4,1);return;
            end
            nodes=st.nodeResults();
            pressure=double(nodes.pressure_head_m(:));
            quality=st.solveSteadyQuality('chemical');
            chlorine=wdn.consumer_chlorine_constraint(nodes,quality);
            c=[cfg.minimum_pressure+pressure_guard_m-pressure(pidx); ...
                pressure(pidx)-(cfg.maximum_pressure-pressure_guard_m); ...
                chlorine(:)];
        catch
            c=1e3*ones(numel(pidx)*2+4,1);
        end
    end
end

function check=check_epanet(cfg,x,staci_metrics)
wdn.setup_toolkit(cfg);
case_dir=tempname;
mkdir(case_dir);
copyfile(cfg.inp_file,fullfile(case_dir,'fixed_load.inp'),'f');
previous=pwd;
cd(case_dir);
cd_cleanup=onCleanup(@()cd(previous));
if isfield(cfg,'epanet_library') && ~isempty(cfg.epanet_library)
    ep=epanet('fixed_load.inp',cfg.epanet_library);
else
    ep=epanet('fixed_load.inp');
end
ep_cleanup=onCleanup(@()ep.unload());
ep_link_ids=string(ep.getLinkNameID);
[found,idx]=ismember(string(cfg.design_link_ids),ep_link_ids);
assert(all(found),'EPANET TT design-link mismatch');
diameters=double(ep.getLinkDiameter);
diameters(idx)=x;
ep.setLinkDiameter(diameters);
ep.solveCompleteHydraulics;
ep_node_ids=string(ep.getNodeNameID);
[found,pidx]=ismember(string(cfg.pressure_node_ids),ep_node_ids);
assert(all(found),'EPANET TT pressure-node mismatch');
pressure=double(ep.getNodePressure);pressure=pressure(:);
ep.solveCompleteQuality;
chlorine=double(ep.getNodeActualQuality);chlorine=chlorine(:);
[found,cidx]=ismember(string(cfg.quality_node_ids),ep_node_ids);
assert(all(found),'EPANET TT consumer-node mismatch');
[found,si]=ismember(ep_node_ids,string(staci_metrics.node_ids));
assert(all(found),'STACI/EPANET TT node mismatch');
check.minimum_pressure_m=min(pressure(pidx));
check.maximum_pressure_m=max(pressure(pidx));
check.minimum_consumer_chlorine_mgL=min(chlorine(cidx));
check.maximum_abs_assessment_pressure_difference_m= ...
    max(abs(pressure(pidx)-staci_metrics.pressures(si(pidx))));
check.maximum_abs_chlorine_difference_mgL= ...
    max(abs(chlorine-staci_metrics.chlorine(si)));
clear ep_cleanup ep cd_cleanup
end
