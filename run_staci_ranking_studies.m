function run_staci_ranking_studies(staci_root, mex_dir, network_name, objectives, result_dir_override, figure_dir_override)
%RUN_STACI_RANKING_STUDIES Recompute and plot cached STACI ranked-subset GAs.
root = fileparts(mfilename('fullpath'));
addpath(root, fullfile(staci_root,'matlab'), mex_dir);
network_dir = char(fullfile(root,'networks',network_name));
addpath(network_dir);
cfg = network_config(network_dir);
cfg.results_dir = fullfile(network_dir,'results_staci');
cfg.figures_dir = fullfile(network_dir,'figures_staci');
if nargin>=5 && ~isempty(result_dir_override)
    cfg.results_dir=char(result_dir_override);
end
if nargin>=6 && ~isempty(figure_dir_override)
    cfg.figures_dir=char(figure_dir_override);
end
cfg.ranking.cache_dir=fullfile(cfg.results_dir,'ranking_cache');
if ~isfolder(cfg.figures_dir),mkdir(cfg.figures_dir);end
if nargin < 4 || isempty(objectives)
    objectives = {'cost','hydraulic_entropy', ...
        'chlorine_concentration','chlorine_entropy'};
end
input_file = fullfile(network_dir,'input','network_staci_fixed_load.inp');
if strcmp(network_name,'balerma')
    cfg.branch_hop_weighting=balerma_connected_branch_weights(cfg);
end
branch_study_file=fullfile(cfg.results_dir,'ranking_branch_hop_study.mat');
if ~strcmp(network_name,'balerma') && ...
        ~any(strcmp(string(objectives),'branch_hop_weighted_entropy')) && ...
        isfile(branch_study_file)
    fixed=load(branch_study_file,'cfg');
    cfg.branch_hop_weighting=fixed.cfg.branch_hop_weighting;
elseif ~strcmp(network_name,'balerma') && ...
        any(strcmp(string(objectives),'branch_hop_weighted_entropy'))
    if strcmp(network_name,'anytown')
        reference_saved=load(fullfile(cfg.results_dir, ...
            'branch_hop_weighted_entropy.mat'),'result');
        cfg.branch_hop_weighting= ...
            reference_saved.result.branch_hop_weighting;
    end
end
rank_file = fullfile(cfg.results_dir,'pipe_rankings.mat');
if isfile(rank_file)
    loaded = load(rank_file,'ranking'); ranking = loaded.ranking;
else
    ranking = wdn.rank_pipes_staci(cfg,input_file);
    save(rank_file,'ranking','-v7');
end
rank_count = min(size(ranking.ordered_link_ids,1), ...
    20 + 25*strcmp(network_name,'balerma'));
rank_table = table((1:rank_count)','VariableNames',{'Rank'});
for q = 1:numel(ranking.criterion_keys)
    key = matlab.lang.makeValidName(ranking.criterion_keys{q});
    rank_table.(key) = string(ranking.ordered_link_ids(1:rank_count,q));
end
writetable(rank_table,fullfile(cfg.results_dir, ...
    sprintf('pipe_rankings_top%d.csv',rank_count)));
for objective = string(objectives)
    seed_objective=objective;
    if objective=="branch_hop_weighted_entropy" && ...
            strcmp(network_name,'balerma')
        seed_objective="hydraulic_entropy";
    end
    saved = load(fullfile(cfg.results_dir,seed_objective+'.mat'),'result');
    study = wdn.optimize_staci_ranked_subsets(cfg,ranking,objective, ...
        cfg.ranking.k_values,saved.result,input_file);
    switch objective
        case "cost"
            cost_study = study; %#ok<NASGU>
            filename = 'ranking_cost_study.mat';
            save(fullfile(cfg.results_dir,filename),'cost_study','ranking','cfg','-v7');
        case "hydraulic_entropy"
            entropy_study = study; %#ok<NASGU>
            filename = 'ranking_entropy_study.mat';
            save(fullfile(cfg.results_dir,filename),'entropy_study','ranking','cfg','-v7');
        case "branch_hop_weighted_entropy"
            branch_study = study; %#ok<NASGU>
            save(fullfile(cfg.results_dir,'ranking_branch_hop_study.mat'), ...
                'branch_study','ranking','cfg','-v7');
        case "chlorine_concentration"
            concentration_study = study; %#ok<NASGU>
            filename = 'ranking_chlorine_concentration_study.mat';
            save(fullfile(cfg.results_dir,filename), ...
                'concentration_study','ranking','cfg','-v7');
        case "chlorine_entropy"
            entropy_study = study; %#ok<NASGU>
            filename = 'ranking_chlorine_entropy_study.mat';
            save(fullfile(cfg.results_dir,filename), ...
                'entropy_study','ranking','cfg','-v7');
    end
    wdn.write_ranking_study_csv(cfg,study, ...
        'ranking_'+objective+'_study.csv');
end
generated = fullfile(root,'manuscript','generated','figures');
target_entropy="hydraulic_entropy";
target_file='ranking_entropy_study.mat';
target_field='entropy_study';
if isfile(fullfile(cfg.results_dir,'ranking_branch_hop_study.mat'))
    target_entropy="branch_hop_weighted_entropy";
    target_file='ranking_branch_hop_study.mat';
    target_field='branch_study';
end
if isfile(fullfile(cfg.results_dir,'ranking_cost_study.mat')) && ...
        isfile(fullfile(cfg.results_dir,target_file)) && ...
        any(ismember(string(objectives),["cost",target_entropy])) && ...
        isfile(fullfile(cfg.results_dir,'ranking_cost_study.mat')) && ...
        isfile(fullfile(cfg.results_dir,target_file))
    a=load(fullfile(cfg.results_dir,'ranking_cost_study.mat'),'cost_study');
    if target_entropy=="branch_hop_weighted_entropy"
        a.cost_study=wdn.augment_ranking_branch_metric( ...
            cfg,a.cost_study,input_file);
        cost_branch_study=a.cost_study; %#ok<NASGU>
        save(fullfile(cfg.results_dir,'ranking_cost_branch_hop_study.mat'), ...
            'cost_branch_study','-v7');
    end
    b=load(fullfile(cfg.results_dir,target_file),target_field);
    normalizers=struct();
    files=wdn.plot_ranking_objective_matrix( ...
        cfg,a.cost_study,b.(target_field),normalizers);
    if strcmp(cfg.results_dir,fullfile(network_dir,'results_staci'))
        copy_outputs(files,generated);
    end
end
if all(ismember(["chlorine_concentration","chlorine_entropy"], ...
        string(objectives))) && ...
        isfile(fullfile(cfg.results_dir,'ranking_chlorine_concentration_study.mat')) && ...
        isfile(fullfile(cfg.results_dir,'ranking_chlorine_entropy_study.mat'))
    a=load(fullfile(cfg.results_dir,'ranking_chlorine_concentration_study.mat'), ...
        'concentration_study');
    b=load(fullfile(cfg.results_dir,'ranking_chlorine_entropy_study.mat'), ...
        'entropy_study');
    files=wdn.plot_ranking_chlorine_matrix( ...
        cfg,a.concentration_study,b.entropy_study);
    if strcmp(cfg.results_dir,fullfile(network_dir,'results_staci'))
        copy_outputs(files,generated);
    end
end
end

function copy_outputs(files,generated)
if ~isfolder(generated),mkdir(generated);end
for k=1:numel(files)
    [~,name,ext]=fileparts(files{k});
    copyfile(files{k},fullfile(generated,[name ext]),'f');
end
end
