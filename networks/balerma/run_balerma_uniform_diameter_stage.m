function result_dir = run_balerma_uniform_diameter_stage( ...
        paper_root,staci_root,mex_dir,stage)
%RUN_BALERMA_UNIFORM_DIAMETER_STAGE Resume the 0.1--64-in Balerma study.
% Stages must be run in this order: full, adjudicate, audit,
% rankings, pda, validate. The fresh GA and archived 10--500-mm vectors
% are re-evaluated under common constraints before post-search incumbent
% selection; archived files are never overwritten.
% 'full' runs six independent full-network GAs; 'rankings' runs all six
% objectives on nested K=0,5,20,45,70,90 subsets (at most 19.82%).
% Reservoir nodes are zero-hop supply roots for branch-hop weighting.
% 'pda' replays both the four-reservoir and R44-unavailable states with PDA.
if nargin<4 || isempty(stage),stage='full';end
stage=string(stage);
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(paper_root,'supplementary'), ...
    fullfile(staci_root,'matlab'),mex_dir);
result_dir=fullfile(network_dir,'results_staci_uniform_0p1_64in_sourceentry_v4');
figure_dir=fullfile(network_dir,'figures_staci_uniform_0p1_64in_sourceentry_v4');
cfg=network_config(network_dir);
cfg.objectives=[cfg.objectives,{'branch_hop_weighted_entropy'}];
cfg.branch_hop_weighting=balerma_connected_branch_weights(cfg);
cfg.ranking.k_values=[0,5,20,45,70,90];
cfg.ranking.max_rank_display=90;
cfg.ranking.figure_basename='balerma_common_cost_branch_rankings';
cfg.ranking.chlorine_figure_basename='balerma_common_chlorine_rankings';
cfg.results_dir=result_dir;
cfg.figures_dir=figure_dir;
cfg.ranking.cache_dir=fullfile(result_dir,'ranking_cache');
assert(cfg.minimum_diameter==2.54 && cfg.maximum_diameter==1625.6, ...
    'Balerma uniform-diameter bounds must be 0.1--64 in');
assert(isequal(sort(string(cfg.source_node_ids(:))), ...
    sort(["38";"43";"44";"88"])), ...
    'All four physical reservoirs must be present in nominal design');
assert(~strcmp(result_dir,fullfile(network_dir,'results_staci')), ...
    'The staged run must not overwrite archived Balerma data');
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
run_id='balerma_four_reservoirs_zero_hop_diameter_0p1_64in_v4';
objectives=string(cfg.objectives);
switch stage
    case "full"
        if ~isfolder(result_dir),mkdir(result_dir);end
        cfg.ga.display='final';
        cfg.ga.maximum_wall_seconds=7200;
        % Earlier 10--500-mm vectors lie inside the common diameter range.
        % Supply them as in-memory candidates; every candidate is freshly
        % checked against the common pressure and chlorine constraints.
        legacy_dir=fullfile(network_dir,'results_staci');
        legacy_seeds=zeros(0,numel(cfg.design_link_ids));
        legacy_cfg=network_config(network_dir);
        for legacy_name=[string(legacy_cfg.objectives), ...
                "branch_hop_weighted_entropy_rank45"]
            old_file=fullfile(legacy_dir,legacy_name+'.mat');
            if ~isfile(old_file),continue;end
            old=load(old_file,'result');
            x_old=double(old.result.design_diameters(:)');
            if numel(x_old)==numel(cfg.design_link_ids)
                legacy_seeds(end+1,:)=x_old; %#ok<AGROW>
            end
        end
        cfg.ga.additional_seed_designs=legacy_seeds;
        for objective=objectives
            target=fullfile(result_dir,objective+'.mat');
            if isfile(target)
                saved=load(target,'result');
                assert(isfield(saved.result,'constraint_set_id') && ...
                    strcmp(saved.result.constraint_set_id,cfg.constraint_set_id) && ...
                    saved.result.minimum_diameter==cfg.minimum_diameter && ...
                    saved.result.maximum_diameter==cfg.maximum_diameter && ...
                    (~strcmp(objective,'branch_hop_weighted_entropy') || ...
                    (isfield(saved.result,'branch_hop_weighting') && ...
                    isfield(saved.result.branch_hop_weighting,'version') && ...
                    strcmp(saved.result.branch_hop_weighting.version, ...
                    cfg.branch_hop_weighting.version))), ...
                    'A saved result has incompatible diameter bounds: %s',target);
                fprintf('SKIP Balerma/%s: matching staged result exists\n',objective);
                continue
            end
            fprintf('START Balerma/%s, diameter range 0.1--64 in\n',objective);
            result=wdn.optimize_staci_single_objective( ...
                cfg,char(objective),input_file,target);
            result.uniform_diameter_recalculation_id=run_id;
            save(target,'result','-v7');
            fprintf('DONE Balerma/%s: %d generations, %.1f s\n', ...
                objective,result.ga_last_generation,result.elapsed_time_seconds);
        end
    case "adjudicate"
        require_full_results(result_dir,objectives,cfg);
        adjudicate_balerma_common_elites( ...
            paper_root,staci_root,mex_dir,result_dir);
    case "audit"
        require_full_results(result_dir,objectives,cfg);
        finalize_balerma_connected_full( ...
            paper_root,staci_root,mex_dir,result_dir,cfg);
    case "rankings"
        require_full_results(result_dir,objectives,cfg);
        run_staci_ranking_studies(staci_root,mex_dir,'balerma', ...
            objectives,result_dir,figure_dir,cfg);
    case "pda"
        require_full_results(result_dir,objectives,cfg);
        run_balerma_uniform_pda_replay( ...
            paper_root,staci_root,mex_dir,result_dir,"R44");
    case "validate"
        require_full_results(result_dir,objectives,cfg);
        out=fullfile(paper_root,'supplementary','results', ...
            'validation_balerma_uniform_0p1_64in_zero_hop_v4');
        validate_staci_final_designs(staci_root,mex_dir,out, ...
            'balerma',objectives, ...
            [],result_dir);
    otherwise
        error('Unknown Balerma stage: %s',stage);
end
end

function require_full_results(folder,objectives,cfg)
for objective=objectives
    target=fullfile(folder,objective+'.mat');
    assert(isfile(target),'Missing Balerma full design: %s',target);
    saved=load(target,'result');
    assert(isfield(saved.result,'constraint_set_id') && ...
        strcmp(saved.result.constraint_set_id,cfg.constraint_set_id) && ...
        saved.result.minimum_diameter==cfg.minimum_diameter && ...
        saved.result.maximum_diameter==cfg.maximum_diameter, ...
        'Balerma full design uses another diameter range: %s',target);
    if strcmp(objective,'branch_hop_weighted_entropy')
        assert(isfield(saved.result,'branch_hop_weighting') && ...
            isfield(saved.result.branch_hop_weighting,'version') && ...
            strcmp(saved.result.branch_hop_weighting.version, ...
            cfg.branch_hop_weighting.version), ...
            'Balerma branch-hop result uses obsolete source weights: %s',target);
    end
end
end
