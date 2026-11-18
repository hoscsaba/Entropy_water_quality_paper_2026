function report=adopt_balerma_r38_refined_designs(paper_root,staci_root,mex_dir)
%ADOPT_BALERMA_R38_REFINED_DESIGNS Audit and select final full-network designs.
% Compare the originally saved design, the rank-seeded full GA, and (for
% branch-hop) the Pareto-seeded full GA using fresh, in-memory STACI solves.
% A feasible K=90 ranking design is also considered, so a later full GA
% cannot accidentally discard the stronger feasible starting point.
% Originals are archived once. The six selected vectors are then passed to
% the ordinary cross-objective adjudication and downstream EPANET/PDA checks.
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
names=string(cfg.objectives(:));
ranking=load(fullfile(cfg.results_dir,'pipe_rankings.mat'),'ranking');
criteria=ranking.ranking.criterion_keys;
st=StaciModel(cfg.inp_file);
release=onCleanup(@()st.release()); %#ok<NASGU>
[links,original]=wdn.staci_input_link_template(cfg.inp_file,st,0.001);
archive=fullfile(cfg.results_dir,'pre_rank_refinement');
if ~isfolder(archive),mkdir(archive);end
rows=cell(numel(names),1);
for j=1:numel(names)
    objective=names(j);
    target=fullfile(cfg.results_dir,objective+".mat");
    old=load(target,'result');
    candidates={old.result};
    labels="previous selected";
    files=fullfile(cfg.results_dir,'refined_ga', ...
        objective+["_from_ranked.mat","_from_pareto.mat"]);
    for f=1:numel(files)
        if ~isfile(files(f)),continue;end
        candidate=load(files(f),'result');
        assert(strcmp(candidate.result.constraint_set_id, ...
            cfg.constraint_set_id),'Incompatible refined candidate');
        candidates{end+1}=candidate.result; %#ok<AGROW>
        labels(end+1)=string(files(f)); %#ok<AGROW>
    end
    for c=1:numel(criteria)
        rank_file=fullfile(cfg.results_dir,'ranking_cache', ...
            char(objective),criteria{c},'k_090.mat');
        if ~isfile(rank_file),continue;end
        saved=load(rank_file,'entry');
        rank_result=old.result;
        rank_result.design_diameters=double(saved.entry.design_diameters(:)');
        rank_result.seed_source=['K=90 ranked subset: ' criteria{c}];
        candidates{end+1}=rank_result; %#ok<AGROW>
        labels(end+1)=string(rank_file); %#ok<AGROW>
    end
    best_idx=0;best_value=NaN;best_metrics=[];best_violation=NaN;
    for c=1:numel(candidates)
        [metrics,violation]=wdn.evaluate_staci_design(st,cfg, ...
            candidates{c}.design_diameters,links,original);
        if violation>cfg.ga.constraint_tolerance,continue;end
        value=double(metrics.(char(objective)));
        if best_idx==0 || (j==1 && value<best_value-1e-8) || ...
                (j~=1 && value>best_value+1e-8)
            best_idx=c;best_value=value;best_metrics=metrics;
            best_violation=violation;
        end
    end
    assert(best_idx>0,'No feasible candidate for %s',objective);
    result=candidates{best_idx};
    result.metrics=best_metrics;
    result.max_constraint_violation=best_violation;
    result.optimizer_value=best_value;
    if j~=1,result.optimizer_value=-best_value;end
    result.selection_source=char(labels(best_idx));
    result.selected_after_refinement=true;
    if contains(labels(best_idx),'ranking_cache')
        result.ga_fval_refers_to_pre_adjudication_search=true;
        result.incumbent_source='feasible K=90 ranked-subset checkpoint';
        result.full_diameters=old.result.full_diameters;
        [found,positions]=ismember(string(result.design_link_ids(:)), ...
            string(result.full_link_ids(:)));
        if all(found) && numel(result.full_diameters)==numel(result.full_link_ids)
            result.full_diameters(positions)=result.design_diameters;
        else
            error('Cannot form full diameter vector for ranked checkpoint');
        end
        result.metrics.full_diameters=result.full_diameters;
    end
    prior=fullfile(archive,objective+".mat");
    if ~isfile(prior),copyfile(target,prior);end
    save(target,'result','-v7');
    cache=fullfile(cfg.results_dir,'pda_replay_cache', ...
        'all_four_protected',objective+".mat");
    if isfile(cache),delete(cache);end
    rows{j}=table(objective,labels(best_idx),best_value,best_violation, ...
        'VariableNames',{'Objective','SelectedFrom','ObjectiveValue', ...
        'MaxConstraintViolation'});
end
report=vertcat(rows{:});
writetable(report,fullfile(cfg.results_dir,'refinement_selection.csv'));
clear release st
adjudicate_balerma_r38_designs(paper_root,staci_root,mex_dir);
disp(report);
end
