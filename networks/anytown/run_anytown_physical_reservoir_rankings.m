function run_anytown_physical_reservoir_rankings( ...
        paper_root,staci_root,mex_dir,objectives,nominal_variant, ...
        result_dir_override,make_plots)
%RUN_ANYTOWN_PHYSICAL_RESERVOIR_RANKINGS Resumable ranked-subset study.
% The optional nominal variant selects physical R65/R165 sources or
% zero-flow anchors. Each criterion/objective/K has an independent cached
% optimization in the variant result directory; extending K reuses it.
if nargin<4 || isempty(objectives)
    objectives=["cost","hydraulic_entropy", ...
        "branch_hop_weighted_entropy", ...
        "chlorine_concentration","chlorine_entropy","todini"];
end
objectives=string(objectives);
if nargin<5,nominal_variant="physical_reservoirs";end
if nargin<6,result_dir_override=[];end
if nargin<7,make_plots=true;end
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','anytown');
addpath(network_dir);
if string(nominal_variant)=="anchor_replay"
    cfg=network_config_anchor_replay(network_dir);
else
    assert(string(nominal_variant)=="physical_reservoirs", ...
        'Unknown nominal variant');
    cfg=network_config_physical_reservoirs(network_dir);
end
if nargin>=6 && ~isempty(result_dir_override)
    cfg.results_dir=char(result_dir_override);
    cfg.figures_dir=fullfile(cfg.results_dir,'figures');
    cfg.ranking.cache_dir=fullfile(cfg.results_dir,'ranking_cache');
    if ~isfolder(cfg.results_dir),mkdir(cfg.results_dir);end
end
branch=load(fullfile(cfg.results_dir, ...
    'branch_hop_weighted_entropy.mat'),'result');
cfg.branch_hop_weighting=branch.result.branch_hop_weighting;
rank_file=fullfile(cfg.results_dir,'pipe_rankings.mat');
reference_model=StaciModel(cfg.inp_file);
release_reference=onCleanup(@()reference_model.release());
input_x=double(reference_model.getLinkProperty( ...
    string(cfg.design_link_ids(:)),'diameter_m'));
input_x=input_x(:)/0.0254;
clear release_reference reference_model
expected_reference=input_x;
if isfield(cfg.ranking,'reference_design') && ...
        ~isempty(cfg.ranking.reference_design)
    expected_reference=double(cfg.ranking.reference_design(:));
elseif isfield(cfg,'pressure_anchor_node_ids') && ...
        ~isempty(cfg.pressure_anchor_node_ids) && ...
        isfield(cfg.ga,'feasible_interpolation_to_upper')
    expected_reference=input_x+cfg.ga.feasible_interpolation_to_upper* ...
        (cfg.maximum_diameter-input_x);
end
ranking_is_current=false;
if isfile(rank_file)
    saved=load(rank_file,'ranking');ranking=saved.ranking;
    ranking_is_current=isfield(ranking,'reference_design') && ...
        numel(ranking.reference_design)==numel(expected_reference) && ...
        max(abs(double(ranking.reference_design(:))- ...
        expected_reference))<1e-10;
end
if ~ranking_is_current
    % The saved pipe order is specific to its nominal diameter reference.
    ranking=wdn.rank_pipes_staci(cfg,cfg.inp_file);
    save(rank_file,'ranking','-v7');
end
rank_table=table((1:20)','VariableNames',{'Rank'});
for q=1:numel(ranking.criterion_keys)
    rank_table.(ranking.criterion_keys{q})= ...
        string(ranking.ordered_link_ids(1:20,q));
end
writetable(rank_table,fullfile(cfg.results_dir,'pipe_rankings_top20.csv'));
fprintf('Original reference max constraint violation: %.5g m\n', ...
    ranking.reference_constraint_violation);
for objective=objectives
    saved=load(fullfile(cfg.results_dir,objective+'.mat'),'result');
    study=wdn.optimize_staci_ranked_subsets(cfg,ranking,objective, ...
        cfg.ranking.k_values,saved.result,cfg.inp_file);
    out=fullfile(cfg.results_dir,'ranking_'+objective+'_study.mat');
    save(out,'study','ranking','-v7');
    wdn.write_ranking_study_csv(cfg,study, ...
        'ranking_'+objective+'_study.csv');
end
if make_plots
    cost_file=fullfile(cfg.results_dir,'ranking_cost_study.mat');
    branch_file=fullfile(cfg.results_dir, ...
        'ranking_branch_hop_weighted_entropy_study.mat');
    if isfile(cost_file) && isfile(branch_file)
        a=load(cost_file,'study');b=load(branch_file,'study');
        wdn.plot_ranking_objective_matrix(cfg,a.study,b.study,struct());
    end
    cl_file=fullfile(cfg.results_dir,'ranking_chlorine_concentration_study.mat');
    clent_file=fullfile(cfg.results_dir,'ranking_chlorine_entropy_study.mat');
    if isfile(cl_file) && isfile(clent_file)
        a=load(cl_file,'study');b=load(clent_file,'study');
        wdn.plot_ranking_chlorine_matrix(cfg,a.study,b.study);
    end
    hyd_file=fullfile(cfg.results_dir,'ranking_hydraulic_entropy_study.mat');
    tod_file=fullfile(cfg.results_dir,'ranking_todini_study.mat');
    if isfile(hyd_file) && isfile(tod_file)
        a=load(hyd_file,'study');b=load(tod_file,'study');
        wdn.plot_ranking_pair_matrix(cfg,a.study,b.study, ...
            'anytown_hydraulic_todini_rankings');
    end
end
end
