function audit=adjudicate_balerma_common_elites( ...
        paper_root,staci_root,mex_dir,result_dir)
%ADJUDICATE_BALERMA_COMMON_ELITES Keep the best verified feasible incumbent.
% The six new GAs and earlier 10--500-mm vectors form a finite candidate
% pool. Every vector is re-evaluated on the same common-bound STACI model.
% This is post-search selection, not a new GA or a claim of global optimality.
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
if nargin<4 || isempty(result_dir)
    result_dir=fullfile(network_dir, ...
        'results_staci_uniform_0p1_64in_staging');
end
cfg=network_config(network_dir);
cfg.branch_hop_weighting=balerma_connected_branch_weights(cfg);
objectives=["cost","hydraulic_entropy", ...
    "branch_hop_weighted_entropy","chlorine_concentration", ...
    "chlorine_entropy","todini"];
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
st=StaciModel(input_file);
release=onCleanup(@()st.release());
[link_order,original_full]=wdn.staci_input_link_template( ...
    input_file,st,0.001);
ids=string(cfg.design_link_ids(:));
original=double(st.getLinkProperty(ids,'diameter_m'))'/0.001;
names="original";
vectors=original;
for source=["common GA","legacy"]
    if source=="common GA",folder=result_dir;
    else,folder=fullfile(network_dir,'results_staci');end
    old_names=objectives;
    if source=="legacy"
        old_names=["cost","hydraulic_entropy", ...
            "branch_hop_weighted_entropy_rank45", ...
            "chlorine_concentration","chlorine_entropy","todini"];
    end
    for objective=old_names
        file=fullfile(folder,objective+'.mat');
        if ~isfile(file),continue;end
        saved=load(file,'result');
        x=double(saved.result.design_diameters(:)');
        if numel(x)~=454 || any(~isfinite(x)),continue;end
        names(end+1,1)=source+":"+objective; %#ok<AGROW>
        vectors(end+1,:)=x; %#ok<AGROW>
    end
end
scores=nan(size(vectors,1),6);
metrics=cell(size(vectors,1),1);
violations=inf(size(vectors,1),1);
for k=1:size(vectors,1)
    try
        [m,v]=wdn.evaluate_staci_design(st,cfg,vectors(k,:), ...
            link_order,original_full);
        metrics{k}=m;
        violations(k)=v;
        scores(k,:)=[m.cost,m.hydraulic_entropy, ...
            m.branch_hop_weighted_entropy,m.chlorine_concentration, ...
            m.chlorine_entropy,m.todini];
    catch exception
        warning('Balerma candidate %s failed: %s',names(k),exception.message);
    end
end
feasible=violations<=cfg.ga.constraint_tolerance & ...
    all(isfinite(scores),2) & ...
    all(vectors>=cfg.minimum_diameter-1e-8 & ...
        vectors<=cfg.maximum_diameter+1e-8,2);
assert(nnz(feasible)>=6,'Too few feasible Balerma candidate designs');
backup_dir=fullfile(result_dir,'pre_adjudication');
if ~isfolder(backup_dir),mkdir(backup_dir);end
rows=cell(6,1);
for j=1:6
    valid=find(feasible);
    if j==1,[~,at]=min(scores(valid,j));
    else,[~,at]=max(scores(valid,j));end
    winner=valid(at);
    target=fullfile(result_dir,objectives(j)+'.mat');
    saved=load(target,'result');
    result=saved.result;
    previous=result.metrics.(char(objectives(j)));
    copyfile(target,fullfile(backup_dir,objectives(j)+'.mat'),'f');
    result.design_diameters=vectors(winner,:);
    result.metrics=metrics{winner};
    result.max_constraint_violation=violations(winner);
    result.full_diameters=result.metrics.full_diameters;
    result.incumbent_source=char(names(winner));
    result.adjudication_candidate_count=nnz(feasible);
    result.adjudicated_at=datetime('now','TimeZone','local');
    if j==1,result.optimizer_value=scores(winner,j);
    else,result.optimizer_value=-scores(winner,j);end
    save(target,'result','-v7');
    rows{j}=table(objectives(j),names(winner),previous, ...
        scores(winner,j),violations(winner),nnz(feasible), ...
        'VariableNames',{'Objective','SelectedSource', ...
        'PreAdjudicationValue','SelectedValue', ...
        'MaxConstraintViolation','FeasibleCandidateCount'});
end
audit=vertcat(rows{:});
writetable(audit,fullfile(result_dir,'elite_adjudication.csv'));
disp(audit);
clear release st
end
