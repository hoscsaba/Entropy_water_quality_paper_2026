function report=adjudicate_balerma_r38_designs( ...
        paper_root,staci_root,mex_dir)
%ADJUDICATE_BALERMA_R38_DESIGNS Select the best saved feasible incumbent.
% All six single-objective searches are run independently. Afterward each
% saved diameter vector is re-evaluated against every objective under the
% same nominal R38-anchor model. A target objective keeps the best feasible
% vector found by ANY of the six searches. This finite-pool adjudication
% makes the cross-objective table internally consistent; it does not claim
% a global optimum. Original target result files are retained separately.
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
names=string(cfg.objectives(:));
n=numel(names);
assert(n==6);
saved=cell(n,1);
scores=zeros(n,n);
metrics=cell(n,1);
violations=zeros(n,1);
st=StaciModel(cfg.inp_file);
release=onCleanup(@()st.release()); %#ok<NASGU>
[links,original]=wdn.staci_input_link_template(cfg.inp_file,st,0.001);
for i=1:n
    file=fullfile(cfg.results_dir,names(i)+".mat");
    data=load(file,'result');
    assert(strcmp(data.result.constraint_set_id,cfg.constraint_set_id));
    saved{i}=data.result;
    [metrics{i},violations(i)]=wdn.evaluate_staci_design( ...
        st,cfg,data.result.design_diameters,links,original);
    assert(violations(i)<=cfg.ga.constraint_tolerance, ...
        'Infeasible Balerma R38 design: %s',names(i));
    m=metrics{i};
    scores(i,:)=[m.cost,m.hydraulic_entropy, ...
        m.branch_hop_weighted_entropy,m.chlorine_concentration, ...
        m.chlorine_entropy,m.todini];
end
selection=zeros(n,1);
[~,selection(1)]=min(scores(:,1));
for j=2:n,[~,selection(j)]=max(scores(:,j));end
archive=fullfile(cfg.results_dir,'pre_adjudication');
if ~isfolder(archive),mkdir(archive);end
for j=1:n
    target=fullfile(cfg.results_dir,names(j)+".mat");
    prior=fullfile(archive,names(j)+".mat");
    if ~isfile(prior),copyfile(target,prior);end
    if selection(j)==j,continue;end
    result=saved{j};
    winner=saved{selection(j)};
    result.design_diameters=winner.design_diameters;
    result.full_diameters=winner.full_diameters;
    result.metrics=metrics{selection(j)};
    result.max_constraint_violation=violations(selection(j));
    result.optimizer_value=scores(selection(j),j);
    if j~=1,result.optimizer_value=-result.optimizer_value;end
    result.incumbent_source=char("cross-objective adjudication: "+ ...
        names(selection(j)));
    result.adjudicated_source_objective=char(names(selection(j)));
    result.adjudicated_from=fullfile('pre_adjudication', ...
        names(selection(j))+".mat");
    result.post_search_adjudicated=true;
    result.adjudication_pool_size=n;
    result.ga_fval_refers_to_pre_adjudication_search=true;
    save(target,'result','-v7');
    cache=fullfile(cfg.results_dir,'pda_replay_cache', ...
        'all_four_protected',names(j)+".mat");
    if isfile(cache),delete(cache);end
end
report=table(names,names(selection), ...
    scores(sub2ind(size(scores),selection,(1:n)')), ...
    diag(scores), ...
    'VariableNames',{'Objective','SelectedFrom', ...
    'SelectedObjectiveValue','OwnSearchObjectiveValue'});
writetable(report,fullfile(cfg.results_dir,'cross_adjudication.csv'));
disp(report);
end
