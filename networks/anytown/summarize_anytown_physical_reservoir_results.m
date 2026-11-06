function [normalized,raw] = summarize_anytown_physical_reservoir_results( ...
        paper_root,staci_root,mex_dir,nominal_variant)
%SUMMARIZE_ANYTOWN_PHYSICAL_RESERVOIR_RESULTS Six-design objective audit.
% Every saved diameter vector is evaluated on the same nominal INP for the
% selected source variant. The fixed topology branch-hop weights are
% loaded from the branch-hop design; no optimization is rerun.

addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','anytown');
addpath(network_dir);
if nargin<4,nominal_variant="physical_reservoirs";end
if string(nominal_variant)=="anchor_replay"
    cfg=network_config_anchor_replay(network_dir);
else
    assert(string(nominal_variant)=="physical_reservoirs", ...
        'Unknown nominal variant');
    cfg=network_config_physical_reservoirs(network_dir);
end
folder=cfg.results_dir;
names=["cost","hydraulic_entropy", ...
    "branch_hop_weighted_entropy","chlorine_concentration", ...
    "chlorine_entropy","todini"];
labels=["Cost","Flow entropy","Branch-hop entropy", ...
    "Cl concentration","Cl entropy","Todini"];
branch=load(fullfile(folder,'branch_hop_weighted_entropy.mat'),'result');
weight=branch.result.branch_hop_weighting;
model=StaciModel(cfg.inp_file);
cleanup=onCleanup(@()model.release());
values=zeros(6,6);
generations=zeros(6,1);evaluations=zeros(6,1);wall=zeros(6,1);
violation=zeros(6,1);
min_pressure=zeros(6,1);min_chlorine=zeros(6,1);
for k=1:6
    saved=load(fullfile(folder,names(k)+'.mat'),'result');
    r=saved.result;
    model.setLinkProperty(string(cfg.design_link_ids(:)), ...
        'diameter_m',double(r.design_diameters(:))*0.0254);
    assert(model.solveHydraulics().converged, ...
        'Saved design failed nominal hydraulic replay');
    nodes=model.nodeResults();
    [found,ix]=ismember(string(nodes.id(:)),string(weight.node_ids(:)));
    assert(all(found),'Branch-hop node weights do not align');
    branch_score=wdn.source_distance_weighted_entropy( ...
        model,cfg,double(weight.weights(ix)));
    m=r.metrics;
    values(k,:)=[m.cost,m.hydraulic_entropy,branch_score, ...
        m.chlorine_concentration,m.chlorine_entropy,m.todini];
    generations(k)=r.ga_last_generation;
    evaluations(k)=r.output.funccount;
    wall(k)=r.elapsed_time_seconds;
    violation(k)=r.max_constraint_violation;
    [found,pi]=ismember(string(cfg.pressure_node_ids(:)), ...
        string(m.node_ids(:)));
    assert(all(found),'Pressure assessment node missing');
    min_pressure(k)=min(double(m.pressures(pi)));
    min_chlorine(k)=m.minimum_consumer_chlorine_mgL;
end
vars={'Cost','FlowEntropy','BranchHopEntropy', ...
    'ChlorineConcentration','ChlorineEntropy','Todini'};
raw=array2table(values,'VariableNames',vars);
raw.OptimizedFor=labels';
raw=movevars(raw,'OptimizedFor','Before',1);
display_values=values;
display_values(:,1)=values(:,1)/min(values(:,1));
for k=2:6
    display_values(:,k)=values(:,k)/max(values(:,k));
end
normalized=array2table(display_values,'VariableNames',vars);
normalized.OptimizedFor=labels';
normalized=movevars(normalized,'OptimizedFor','Before',1);
ga=table(labels',generations,evaluations,wall,violation, ...
    min_pressure,min_chlorine,'VariableNames', ...
    {'OptimizedFor','Generations','Evaluations','WallSeconds', ...
    'MaxConstraintViolation','MinimumConsumerPressure_psi', ...
    'MinimumMaterialConsumerChlorine_mgL'});
writetable(raw,fullfile(folder,'cross_evaluation_six_raw.csv'));
writetable(normalized,fullfile(folder,'cross_evaluation_six.csv'));
writetable(ga,fullfile(folder,'ga_stop_six.csv'));
disp(raw);disp(ga);
end
