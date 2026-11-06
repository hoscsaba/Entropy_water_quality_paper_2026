function run_anytown_anchor_replay_optimizations( ...
        paper_root,staci_root,mex_dir,objectives)
%RUN_ANYTOWN_ANCHOR_REPLAY_OPTIMIZATIONS Six pump-only nominal searches.
% R65/R165 are zero-flow pressure anchors during design. The pump supplies
% all demand. Saved final vectors and the local feasible seed are warm starts;
% each candidate and accepted endpoint is evaluated on the anchor INP.
% No candidate-level files are written.
if nargin<4 || isempty(objectives)
    objectives=["cost","hydraulic_entropy", ...
        "branch_hop_weighted_entropy","chlorine_concentration", ...
        "chlorine_entropy","todini"];
end
objectives=string(objectives(:));
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','anytown');
addpath(network_dir);
cfg=network_config_anchor_replay(network_dir);
if ~isfolder(cfg.results_dir),mkdir(cfg.results_dir);end
cfg.branch_hop_weighting=anytown_anchor_replay_weights(cfg);
w=cfg.branch_hop_weighting;
T=table(string(w.node_ids(:)),w.branch_hops(:),w.weights(:), ...
    w.physical_degree(:),w.demand_exit(:),'VariableNames', ...
    {'NodeID','BranchHops','Weight','PhysicalDegree','DemandExit'});
writetable(T,fullfile(cfg.results_dir,'topology_branch_hop_weights.csv'));
% The released final vectors also serve as portable warm starts. Do not
% depend on superseded, machine-specific result directories.
seed_folders=string(cfg.results_dir);
seed_names=string(cfg.objectives);
seeds=zeros(0,numel(cfg.design_link_ids));
for folder=seed_folders
    for name=seed_names
        path=fullfile(folder,name+'.mat');
        if ~isfile(path),continue,end
        archived=load(path,'result');
        if numel(archived.result.design_diameters)==numel(cfg.design_link_ids)
            seeds(end+1,:)=double(archived.result.design_diameters(:)'); %#ok<AGROW>
        end
    end
end
cfg.ga.additional_seed_designs=unique(seeds,'rows','stable');
local_seed=fullfile(cfg.results_dir,'cost_local_seed.mat');
if isfile(local_seed)
    repaired=load(local_seed,'x');
    cfg.ga.additional_seed_designs(end+1,:)=double(repaired.x(:)');
end
for objective=objectives'
    assert(ismember(objective,string(cfg.objectives)), ...
        'Unsupported objective %s',objective);
    output=fullfile(cfg.results_dir,objective+'.mat');
    if isfile(output)
        saved=load(output,'result');
        assert(strcmp(saved.result.input_file,fullfile('networks', ...
            'anytown','input','network_anchor_replay.inp')), ...
            'An incompatible result occupies the anchor-replay folder');
        assert(isfield(saved.result,'pressure_to_head_ft_per_psi') && ...
            abs(saved.result.pressure_to_head_ft_per_psi- ...
            cfg.pressure_to_head)<1e-8, ...
            'A saved design used another pressure conversion');
        assert(isfield(saved.result,'pressure_guard_psi') && ...
            abs(saved.result.pressure_guard_psi- ...
            cfg.ga.pressure_numerical_guard_psi)<1e-10 && ...
            abs(saved.result.anchor_numerical_guard_ft- ...
            cfg.ga.anchor_numerical_guard_ft)<1e-10, ...
            'A saved design used another numerical constraint margin');
        audit_nominal_source(saved.result,cfg);
        fprintf('Reusing audited anchor result: %s\n',objective);
        continue
    end
    cfg.ga.random_seed=1993;
    if objective=="branch_hop_weighted_entropy"
        cfg.ga.random_seed=20261106;
    end
    result=wdn.optimize_staci_single_objective(cfg,char(objective), ...
        cfg.inp_file,output);
    result=audit_nominal_source(result,cfg);
    save(output,'result','-v7');
    fprintf('%s: generation %d, evaluations %d, constraint %.6g\n', ...
        objective,result.ga_last_generation,result.output.funccount, ...
        result.max_constraint_violation);
end
end

function result=audit_nominal_source(result,cfg)
% Independent fresh-model replay catches warm-start-dependent roundoff at
% nearly active pressure and anchor bounds before a result is accepted.
st=StaciModel(cfg.inp_file);
release=onCleanup(@()st.release());
[link_order,full_original]=wdn.staci_input_link_template( ...
    cfg.inp_file,st,0.0254);
[m,violation]=wdn.evaluate_staci_design(st,cfg, ...
    result.design_diameters,link_order,full_original);
assert(violation<=cfg.ga.constraint_tolerance, ...
    'Saved nominal anchor design violates hydraulic constraints on fresh replay');
if ismember(string(result.objective), ...
        ["chlorine_concentration","chlorine_entropy"])
    assert(m.minimum_consumer_chlorine_mgL>=0.2-1e-6, ...
        'Saved chlorine-directed design violates consumer residual floor');
end
result.metrics=m;
result.max_constraint_violation=violation;
ids=string(m.link_ids(:));
q=double(m.flows_m3s(:));
for id=["78","80"]
    k=find(ids==id,1);
    assert(isscalar(k) && abs(q(k))<1e-9, ...
        'Pressure-anchor connector %s carries water',id);
end
pump=find(ids=="82",1);
assert(isscalar(pump) && q(pump)>0,'Pump 82 is not supplying');
% The input demand sum is 0.282644... m^3/s at the frozen 0.7 load.
assert(abs(q(pump)-0.282644079872)<1e-6, ...
    'Pump flow does not cover all nominal demand');
node_ids=string(m.node_ids(:));
for id=["65","165"]
    k=find(node_ids==id,1);
    assert(isscalar(k) && abs(m.heads(k)-215)<= ...
        cfg.pressure_anchor_head_tolerance+5e-4, ...
        'Pressure anchor %s has the wrong head',id);
end
end
