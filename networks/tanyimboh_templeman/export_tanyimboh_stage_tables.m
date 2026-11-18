function [nominal,validation,service] = export_tanyimboh_stage_tables(paper_root,staci_root,mex_dir,results_dir,validation_dir)
%EXPORT_TANYIMBOH_STAGE_TABLES Re-evaluate saved v2 designs and export data.
% No optimization is done here. Each saved diameter vector is solved once in
% a fresh, resident STACI model with the final mass-splitting definition.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
nd=fullfile(paper_root,'networks','tanyimboh_templeman');addpath(nd);
cfg=network_config(nd);cfg.branch_hop_weighting=tanyimboh_branch_hop_weights(cfg);
folder=fullfile(nd,'results_staci_10_120_clsplit_v2');
if nargin>=4 && ~isempty(results_dir),folder=char(results_dir);end
inp=fullfile(nd,'input','network_staci_fixed_load.inp');
objectives=["cost","hydraulic_entropy","branch_hop_weighted_entropy", ...
    "chlorine_concentration","chlorine_entropy","todini"];
rows=cell(numel(objectives),1);
for k=1:numel(objectives)
    saved=load(fullfile(folder,objectives(k)+'.mat'),'result');
    st=StaciModel(inp);release=onCleanup(@()st.release());
    [order,original]=wdn.staci_input_link_template(inp,st,0.001);
    [m,v]=wdn.evaluate_staci_design(st,cfg, ...
        saved.result.design_diameters,order,original);
    assert(v<=cfg.ga.constraint_tolerance,'Saved nominal design is infeasible');
    rows{k}=table(objectives(k),m.cost,m.hydraulic_entropy, ...
        m.branch_hop_weighted_entropy,m.chlorine_concentration, ...
        m.chlorine_entropy,m.todini,m.minimum_consumer_chlorine_mgL, ...
        min(m.pressures(ismember(string(m.node_ids),string(cfg.pressure_node_ids)))), ...
        saved.result.ga_last_generation,saved.result.elapsed_time_seconds, ...
        'VariableNames',{'Objective','Cost','FlowEntropy','BranchHopEntropy', ...
        'ChlorineConcentration','ChlorineEntropy','Todini', ...
        'MinimumConsumerChlorine_mgL','MinimumPressure_m', ...
        'GAGenerations','GASolveTime_s'});
    clear release st
end
nominal=vertcat(rows{:});
writetable(nominal,fullfile(folder,'nominal_six_cross_evaluation.csv'));
metric_names={'Cost','FlowEntropy','BranchHopEntropy', ...
    'ChlorineConcentration','ChlorineEntropy','Todini'};
relative=nominal(:,[{'Objective'},metric_names]);
relative.Cost=nominal.Cost/min(nominal.Cost);
for k=2:numel(metric_names)
    name=metric_names{k};
    relative.(name)=nominal.(name)/max(nominal.(name));
end
writetable(relative,fullfile(folder,'nominal_six_cross_evaluation_relative.csv'));
service=readtable(fullfile(folder,'pda_service_six.csv'));
if nargin<5 || isempty(validation_dir)
    validation_dir=fullfile(paper_root,'supplementary','results', ...
        'validation_tt_10_120_clsplit_v2');
end
validation=readtable(fullfile(validation_dir,'staci_epanet_tanyimboh_six.csv'));
end
