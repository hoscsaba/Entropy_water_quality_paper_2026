function run_staci_ranking_studies(staci_root, mex_dir, network_name, objectives)
%RUN_STACI_RANKING_STUDIES Recompute and plot cached STACI ranked-subset GAs.
root = fileparts(mfilename('fullpath'));
addpath(root, fullfile(staci_root,'matlab'), mex_dir);
network_dir = char(fullfile(root,'networks',network_name));
addpath(network_dir);
cfg = network_config(network_dir);
cfg.results_dir = fullfile(network_dir,'results_staci');
cfg.figures_dir = fullfile(network_dir,'figures_staci');
if ~isfolder(cfg.figures_dir),mkdir(cfg.figures_dir);end
if nargin < 4 || isempty(objectives)
    objectives = {'cost','hydraulic_entropy', ...
        'chlorine_concentration','chlorine_entropy'};
end
input_file = fullfile(network_dir,'input','network_staci_fixed_load.inp');
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
    saved = load(fullfile(cfg.results_dir,objective+'.mat'),'result');
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
if all(ismember(["cost","hydraulic_entropy"], string(objectives))) && ...
        isfile(fullfile(cfg.results_dir,'ranking_cost_study.mat')) && ...
        isfile(fullfile(cfg.results_dir,'ranking_entropy_study.mat'))
    a=load(fullfile(cfg.results_dir,'ranking_cost_study.mat'),'cost_study');
    b=load(fullfile(cfg.results_dir,'ranking_entropy_study.mat'),'entropy_study');
    normalizers=struct();
    files=wdn.plot_ranking_objective_matrix( ...
        cfg,a.cost_study,b.entropy_study,normalizers);
    copy_outputs(files,generated);
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
    copy_outputs(files,generated);
end
end

function copy_outputs(files,generated)
if ~isfolder(generated),mkdir(generated);end
for k=1:numel(files)
    [~,name,ext]=fileparts(files{k});
    copyfile(files{k},fullfile(generated,[name ext]),'f');
end
end
