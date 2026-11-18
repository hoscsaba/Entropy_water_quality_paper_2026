function [result,improved]=refine_uniform_endpoint_from_saved_seeds( ...
        staci_root,mex_dir,network_name,objective,stage_name)
%REFINE_UNIFORM_ENDPOINT_FROM_SAVED_SEEDS Continue a common-bound GA.
% Every feasible saved design in this network is a valid seed for every
% objective, because all designs share the same bounds and constraints.
% This is useful when an objective finished before a later search found a
% better design for it. No figures are made.
if nargin<5 || isempty(stage_name)
    if string(network_name)=="anytown"
        stage_name='results_staci_anchor_replay';
    else
        stage_name='results_staci_10_120_clsplit_v2';
    end
end
root=fileparts(mfilename('fullpath'));
nd=fullfile(root,'networks',char(network_name));
addpath(root,nd,fullfile(staci_root,'matlab'),mex_dir);
if string(network_name)=="anytown"
    cfg=network_config_anchor_replay(nd);
    cfg.branch_hop_weighting=anytown_anchor_replay_weights(cfg);
    names=["cost","hydraulic_entropy","branch_hop_weighted_entropy", ...
        "chlorine_concentration","chlorine_entropy","todini"];
else
    assert(string(network_name)=="tanyimboh_templeman", ...
        'Only Anytown and Tanyimboh–Templeman are part of this range study');
    cfg=network_config(nd);
    cfg.inp_file=fullfile(nd,'input','network_staci_fixed_load.inp');
    cfg.branch_hop_weighting=tanyimboh_branch_hop_weights(cfg);
    names=[string(cfg.objectives),"branch_hop_weighted_entropy"];
    cfg.objectives=cellstr(names);
end
assert(ismember(string(objective),names),'Unknown objective');
cfg.results_dir=fullfile(nd,char(stage_name));
seed=zeros(0,numel(cfg.design_link_ids));
for k=1:numel(names)
    saved=load(fullfile(cfg.results_dir,names(k)+'.mat'),'result');
    seed(end+1,:)=double(saved.result.design_diameters(:)'); %#ok<AGROW>
end
cfg.ga.additional_seed_designs=unique(seed,'rows','stable');
cfg.ga.maximum_wall_seconds=7200;
cfg.ga.display='final';
cfg.ga.random_seed=20261113;
target=fullfile(cfg.results_dir,string(objective)+'.mat');
previous=load(target,'result');
candidate_file=fullfile(cfg.results_dir, ...
    string(objective)+'_refinement_candidate.mat');
result=wdn.optimize_staci_single_objective(cfg,char(objective), ...
    cfg.inp_file,candidate_file);
st=StaciModel(cfg.inp_file);
release=onCleanup(@()st.release());
if string(network_name)=="anytown",scale=0.0254;else,scale=0.001;end
[link_order,original]=wdn.staci_input_link_template(cfg.inp_file,st,scale);
[new_metrics,new_violation]=wdn.evaluate_staci_design( ...
    st,cfg,result.design_diameters,link_order,original);
[old_metrics,old_violation]=wdn.evaluate_staci_design( ...
    st,cfg,previous.result.design_diameters,link_order,original);
assert(new_violation<=cfg.ga.constraint_tolerance, ...
    'Refinement candidate fails a shared constraint');
if string(objective)=="cost"
    improved=old_violation>cfg.ga.constraint_tolerance || ...
        new_metrics.cost<old_metrics.cost;
else
    improved=old_violation>cfg.ga.constraint_tolerance || ...
        new_metrics.(char(objective))>old_metrics.(char(objective));
end
if improved
    backup=fullfile(cfg.results_dir, ...
        string(objective)+'_pre_refinement.mat');
    copyfile(target,backup,'f');
    copyfile(candidate_file,target,'f');
end
fprintf('%s/%s refinement: improved=%d, old=%.9g, new=%.9g\n', ...
    network_name,objective,improved,old_metrics.(char(objective)), ...
    new_metrics.(char(objective)));
end
