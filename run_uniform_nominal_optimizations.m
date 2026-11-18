function run_uniform_nominal_optimizations(staci_root,mex_dir,network_names,stage_name)
%RUN_UNIFORM_NOMINAL_OPTIMIZATIONS Refit final designs with common constraints.
% Each objective has the same pressure limits, and every material-demand
% consumer must have stationary chlorine >= 0.2 mg/L. Existing published
% vectors are only warm starts. New results go to separate staging folders;
% an interrupted run resumes without repeating completed objectives.
% Review staged vectors and independent EPANET checks before promotion.
% Balerma has a different R38-anchor boundary and must use its dedicated
% run_balerma_r38_anchor driver; this function handles TT and Anytown only.
if nargin<3 || isempty(network_names)
    network_names=["tanyimboh_templeman","anytown"];
end
if nargin<4 || isempty(stage_name)
    stage_name='reproduction_run';
end
root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(staci_root,'matlab'),mex_dir);
for name=reshape(string(network_names),1,[])
    assert(name=="tanyimboh_templeman" || name=="anytown", ...
        ['Use networks/balerma/run_balerma_r38_anchor.m for Balerma; ', ...
         'the generic driver does not enforce its R38 pressure anchor.']);
    nd=char(fullfile(root,'networks',name));
    addpath(nd,'-begin');
    clear network_config
    if name=="anytown"
        cfg=network_config_anchor_replay(nd);
        cfg.branch_hop_weighting=anytown_anchor_replay_weights(cfg);
        canonical=cfg.results_dir;
        objectives=["cost","hydraulic_entropy", ...
            "branch_hop_weighted_entropy","chlorine_concentration", ...
            "chlorine_entropy","todini"];
    else
        cfg=network_config(nd);
        cfg.inp_file=fullfile(nd,'input','network_staci_fixed_load.inp');
        canonical=cfg.results_dir;
        objectives=string(cfg.objectives);
        if name=="tanyimboh_templeman"
            cfg.branch_hop_weighting=tanyimboh_branch_hop_weights(cfg);
            objectives(end+1)="branch_hop_weighted_entropy";
            cfg.objectives=cellstr(objectives);
        end
    end
    cfg.results_dir=fullfile(nd,char(stage_name));
    if ~isfolder(cfg.results_dir),mkdir(cfg.results_dir);end
    cfg.ga.maximum_wall_seconds=7200;
    cfg.ga.display='final';
    seeds=zeros(0,numel(cfg.design_link_ids));
    % Released endpoints and completed results in this output directory
    % provide warm starts. Every seed is re-evaluated in memory under the
    % current constraint set before it can become an incumbent.
    seed_folders=unique({canonical,cfg.results_dir},'stable');
    for folder_index=1:numel(seed_folders)
        for objective=objectives
            path=fullfile(seed_folders{folder_index},objective+'.mat');
            if ~isfile(path),continue,end
            old=load(path,'result');
            if numel(old.result.design_diameters)==numel(cfg.design_link_ids)
                seeds(end+1,:)=double(old.result.design_diameters(:)'); %#ok<AGROW>
            end
        end
    end
    cfg.ga.additional_seed_designs=unique(seeds,'rows','stable');
    for objective=objectives
        target=fullfile(cfg.results_dir,objective+'.mat');
        if isfile(target)
            saved=load(target,'result');
            assert(isfield(saved.result,'constraint_set_id') && ...
                strcmp(saved.result.constraint_set_id, ...
                'pressure_10_120m_chlorine_mass_split_v2'), ...
                'Staging result has another constraint set: %s',target);
            assert(isfield(saved.result,'minimum_diameter') && ...
                isfield(saved.result,'maximum_diameter') && ...
                abs(saved.result.minimum_diameter-cfg.minimum_diameter)<1e-12 && ...
                abs(saved.result.maximum_diameter-cfg.maximum_diameter)<1e-12, ...
                'Staging result has other diameter bounds: %s',target);
            fprintf('SKIP completed %s/%s\n',name,objective);
            continue
        end
        fprintf('START uniform %s/%s at %s\n',name,objective,datetime('now'));
        if name=="anytown" && objective=="branch_hop_weighted_entropy"
            cfg.ga.random_seed=20261106;
        else
            cfg.ga.random_seed=1993;
        end
        result=wdn.optimize_staci_single_objective(cfg,char(objective), ...
            cfg.inp_file,target);
        fresh=StaciModel(cfg.inp_file);
        release=onCleanup(@()fresh.release());
        if name=="anytown",scale=0.0254;else,scale=0.001;end
        [link_order,original]=wdn.staci_input_link_template( ...
            cfg.inp_file,fresh,scale);
        [metrics,violation]=wdn.evaluate_staci_design(fresh,cfg, ...
            result.design_diameters,link_order,original);
        assert(violation<=cfg.ga.constraint_tolerance && ...
            metrics.minimum_consumer_chlorine_mgL>=0.2-1e-6, ...
            'Fresh nominal replay failed for %s/%s',name,objective);
        clear release fresh
        fprintf('DONE %s/%s: generation %d, %.1f s, residual %.6f mg/L\n', ...
            name,objective,result.ga_last_generation, ...
            result.elapsed_time_seconds,metrics.minimum_consumer_chlorine_mgL);
    end
end
end
