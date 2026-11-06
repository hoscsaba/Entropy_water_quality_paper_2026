function refresh_balerma_branch_hop_tables(paper_root,staci_root,mex_dir,result_dir_override)
%REFRESH_BALERMA_BRANCH_HOP_TABLES Compare the best saved K=45 branch design.
% The branch-hop row optimizes only 45 of 454 diameters. The other five rows
% retain their full-network archived vectors. This distinction must remain
% explicit when interpreting the cross-evaluation and failure tables.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','balerma');
addpath(network_dir);
cfg=network_config(network_dir);
if nargin>=4 && ~isempty(result_dir_override)
    cfg.results_dir=char(result_dir_override);
end
folder=cfg.results_dir;
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
loaded=load(fullfile(folder,'ranking_branch_hop_study.mat'), ...
    'branch_study','cfg');
study=loaded.branch_study;
cfg.branch_hop_weighting=loaded.cfg.branch_hop_weighting;
j=find(study.k==45,1);
assert(~isempty(j),'K=45 branch-hop study is missing');
scores=study.metrics(:,j,strcmp(study.metric_names, ...
    'branch_hop_weighted_entropy'));
scores=reshape(scores,[],1);
scores(~study.is_feasible(:,j))=-inf;
[~,q]=max(scores);
assert(isfinite(scores(q)),'No feasible K=45 branch-hop design');
branch_diameters=reshape(study.designs(q,j,:),[],1);

model=StaciModel(input_file);
cleanup=onCleanup(@() model.release());
[link_order,full_original]=wdn.staci_input_link_template( ...
    input_file,model,0.001);
names=[string(cfg.objectives),"branch_hop_weighted_entropy_rank45"];
labels=["Cost","Hydraulic entropy","Chlorine concentration", ...
    "Chlorine entropy","Todini","Branch-hop entropy"];
raw=zeros(6,6); designs=cell(6,1);
for k=1:6
    if k==6
        x=branch_diameters;
    else
        saved=load(fullfile(folder,names(k)+".mat"),'result');
        x=double(saved.result.design_diameters(:));
    end
    [m,v]=wdn.evaluate_staci_design(model,cfg,x,link_order,full_original);
    assert(v<=cfg.ga.constraint_tolerance, ...
        'Saved Balerma design is pressure-infeasible: %s',names(k));
    designs{k}=x;
    raw(k,:)=[m.cost,m.hydraulic_entropy, ...
        m.branch_hop_weighted_entropy,m.chlorine_concentration, ...
        m.chlorine_entropy,m.todini];
    if k==6
        cache_file=fullfile(cfg.results_dir,'ranking_cache', ...
            'branch_hop_weighted_entropy',study.criterion_keys{q}, ...
            'k_045.mat');
        cached=load(cache_file,'entry');
        result=struct('network_id','balerma', ...
            'objective','branch_hop_weighted_entropy', ...
            'model','staci_steady_first_order', ...
            'design_diameters',x,'metrics',m,'max_constraint_violation',v, ...
            'full_link_ids',{cellstr(string(link_order(:)))}, ...
            'full_diameters',m.full_diameters, ...
            'ranking_criterion',study.criterion_keys{q}, ...
            'optimized_pipe_count',45,'total_pipe_count',numel(x), ...
            'ga_last_generation',cached.entry.generations, ...
            'exitflag',cached.entry.exitflag, ...
            'elapsed_time_seconds',cached.entry.elapsed_seconds);
        save(fullfile(folder,'branch_hop_weighted_entropy_rank45.mat'), ...
            'result','-v7');
    end
end
clear cleanup model
order=[1,2,6,3,4,5];
raw=raw(order,:);
norm=raw;
norm(:,1)=raw(:,1)/min(raw(:,1));
for k=2:6, norm(:,k)=raw(:,k)/max(raw(:,k)); end
vars={'Cost','FlowEntropy','BranchHopEntropy', ...
    'ChlorineConcentration','ChlorineEntropy','Todini'};
raw_table=array2table(raw,'VariableNames',vars);
raw_table.OptimizedFor=labels(order)';
raw_table=movevars(raw_table,'OptimizedFor','Before',1);
norm_table=array2table(norm,'VariableNames',vars);
norm_table.OptimizedFor=labels(order)';
norm_table=movevars(norm_table,'OptimizedFor','Before',1);
writetable(raw_table,fullfile(folder,'cross_evaluation_six_raw.csv'));
writetable(norm_table,fullfile(folder,'cross_evaluation_six.csv'));

run_data=table(strings(6,1),zeros(6,1),nan(6,1), ...
    zeros(6,1),strings(6,1), ...
    'VariableNames',{'Objective','Generations','Evaluations', ...
    'WallSeconds','SearchScope'});
for k=1:5
    saved=load(fullfile(folder,names(k)+".mat"),'result');
    run_data.Objective(k)=labels(k);
    run_data.Generations(k)=saved.result.ga_last_generation;
    run_data.Evaluations(k)=saved.result.output.funccount;
    run_data.WallSeconds(k)=saved.result.elapsed_time_seconds;
    run_data.SearchScope(k)="454 pipes";
end
run_data.Objective(6)=labels(6);
run_data.Generations(6)=cached.entry.generations;
run_data.WallSeconds(6)=cached.entry.elapsed_seconds;
run_data.SearchScope(6)="45 pipes, selected ranking";
writetable(run_data,fullfile(folder,'ga_stop_six.csv'));

stress=readtable(fullfile(folder,'stress_test.csv'));
[extra_stress,dda_scenarios]=wdn.staci_pipe_failure_stress_test( ...
    cfg,designs{6},'Branch-hop entropy',input_file);
stress=[stress;struct2table(extra_stress)];
writetable(stress,fullfile(folder,'stress_test_six.csv'));
writetable(dda_scenarios,fullfile(folder, ...
    'branch_hop_entropy_dda_scenarios.csv'));

pda_file=fullfile(folder,'runtime','network_pda_fixed_load.inp');
wdn.write_staci_pda_input(cfg,input_file,pda_file);
pda=readtable(fullfile(folder,'pda_service_summary.csv'));
[extra_pda,pda_scenarios]=wdn.staci_pda_failure_service( ...
    cfg,designs{6},'Branch-hop entropy',input_file,pda_file);
pda=[pda;extra_pda];
writetable(pda,fullfile(folder,'pda_service_six.csv'));
writetable(pda_scenarios,fullfile(folder, ...
    'branch_hop_entropy_pda_scenarios.csv'));
fprintf('Balerma K=45 branch-hop: ranking %s, score %.6g\n', ...
    study.criterion_keys{q},scores(q));
disp(norm_table); disp(extra_stress); disp(extra_pda);
end
