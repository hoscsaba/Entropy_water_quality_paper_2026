function [all_rows, summary_rows] = export_ranked_progress(paper_root, output_dir)
%EXPORT_RANKED_PROGRESS Fraction of the saved initial-to-full improvement.
% Reads current single-objective and ranked-subset CSV files; it performs no
% optimization or hydraulic calculation. For each objective j and ranking r,
% the reported percentage is
%
%   P_j,r(K) = 100*abs(F_j,r(K)-F_j,0)/abs(F_j,full-F_j,0).
%
% F is cost for the minimized cost objective and the corresponding metric
% for each maximized objective. F_j,0 is the feasible K=0 reference shared
% by the five rankings; F_j,full is the saved objective-specific full-network
% result under the same nominal constraints. These full-network results are
% best found by finite searches, not certified global optima. All saved
% feasible subset objectives improve in the intended direction from K=0,
% so a larger P means more of the attainable saved improvement was reached.
% A value just above 100 is retained if a subset slightly exceeds its saved
% full-network reference. This is especially relevant near numerical ties.
%
% Outputs are ranked_progress_all.csv and ranked_progress_representative.csv.
% The latter contains TT K=2,4; Anytown K=8,20; and Balerma K=45,90.
%
% Usage: addpath(fullfile(paper_root,'manuscript','tables'));
%        export_ranked_progress(paper_root);

if nargin < 1 || isempty(paper_root)
    paper_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin < 2 || isempty(output_dir)
    output_dir = fullfile(paper_root,'manuscript','generated','tables');
end
assert(isfolder(fullfile(paper_root,'networks')), ...
    'Expected a paper checkout containing networks/.');
if ~isfolder(output_dir), mkdir(output_dir); end

configs(1) = make_config('tanyimboh_templeman', ...
    'results_staci_10_120_clsplit_v2', ...
    'nominal_six_cross_evaluation.csv','Objective',8,[2 4]);
configs(2) = make_config('anytown','results_staci_anchor_replay', ...
    'cross_evaluation_six_raw.csv','OptimizedFor',38,[8 20]);
configs(3) = make_config('balerma', ...
    'results_staci_r38_anchor_r44_physical_0p1_64in_v1', ...
    'cross_evaluation_six_raw.csv','OptimizedFor',454,[45 90]);

objective_ids = ["cost";"hydraulic_entropy"; ...
    "branch_hop_weighted_entropy";"chlorine_concentration"; ...
    "chlorine_entropy";"todini"];
rank_columns = ["Cost";"HydraulicEntropy";"BranchHopEntropy"; ...
    "ChlorineConcentration";"ChlorineEntropy";"Todini"];
anytown_full_labels = ["Cost";"Flow entropy";"Branch-hop entropy"; ...
    "Cl concentration";"Cl entropy";"Todini"];

row_template = struct('Network',"",'Objective',"",'K',NaN, ...
    'TotalPipes',NaN,'PipeFractionPct',NaN, ...
    'InitialObjectiveValue',NaN,'FullObjectiveValue',NaN, ...
    'BestRanking',"",'BestObjectiveValue',NaN,'ProgressPct',NaN, ...
    'RunnerUpRanking',"",'RunnerUpObjectiveValue',NaN, ...
    'RunnerUpProgressPct',NaN, ...
    'LeadOverRunnerUpProgressPoints',NaN,'FeasibleRankings',0);
rows = repmat(row_template,0,1);
for network_index = 1:numel(configs)
    cfg = configs(network_index);
    folder = fullfile(paper_root,'networks',cfg.id,cfg.result_folder);
    full_results = readtable(fullfile(folder,cfg.full_file), ...
        'TextType','string');
    for objective_index = 1:numel(objective_ids)
        objective = objective_ids(objective_index);
        rank_column = rank_columns(objective_index);
        full_column = rank_column;
        if objective == "hydraulic_entropy" && cfg.id ~= "balerma"
            full_column = "FlowEntropy";
        end
        full_label = objective;
        if cfg.id == "anytown"
            full_label = anytown_full_labels(objective_index);
        end
        full_labels = string(full_results.(cfg.key_column));
        match = full_labels == full_label;
        assert(nnz(match) == 1, ...
            'Expected one full-network %s row for %s.',objective,cfg.id);
        full_values = double(full_results.(full_column));
        full_value = full_values(match);
        assert(isfinite(full_value) && full_value > 0, ...
            'Invalid full-network objective for %s/%s.',cfg.id,objective);

        rank_file = "ranking_" + objective + "_study.csv";
        if cfg.id == "anytown" && objective == "todini"
            % The published Anytown Todini subset results include the
            % documented constrained local refinement.
            rank_file = "ranking_todini_refined_study.csv";
        end
        ranked = readtable(fullfile(folder,rank_file),'TextType','string');
        value_column = double(ranked.(rank_column));
        k0_rows = double(ranked.K)==0 & logical(ranked.IsFeasible);
        k0_values = value_column(k0_rows);
        assert(numel(k0_values)==5 && all(isfinite(k0_values)), ...
            'Expected five feasible K=0 ranking references.');
        initial_value = k0_values(1);
        assert(max(abs(k0_values-initial_value)) <= ...
            1e-10*max(1,abs(initial_value)), ...
            'K=0 reference differs between rankings.');
        normalizer = abs(full_value-initial_value);
        if normalizer <= 1e-10*max([1,abs(initial_value),abs(full_value)])
            % There is no meaningful initial-to-full percentage if the
            % reference improvement vanishes. Keep raw objective values.
            warning('Progress undefined for %s/%s: full and K=0 agree.', ...
                cfg.id,objective);
            normalizer = NaN;
        end
        counts = sort(unique(double(ranked.K)));
        assert(counts(1)==0 && all(diff(counts) > 0), ...
            'Expected K=0 and strictly increasing pipe counts.');
        for k = counts(:)'
            at_k = double(ranked.K) == k;
            feasible = at_k & logical(ranked.IsFeasible);
            feasible = feasible & isfinite(value_column);
            row = row_template;
            row.Network = cfg.id;
            row.Objective = objective;
            row.K = k;
            row.TotalPipes = cfg.total_pipes;
            row.PipeFractionPct = 100*k/cfg.total_pipes;
            row.InitialObjectiveValue = initial_value;
            row.FullObjectiveValue = full_value;
            row.FeasibleRankings = nnz(feasible);
            if row.FeasibleRankings > 0
                values = value_column(feasible);
                criteria = string(ranked.Criterion(feasible));
                if objective == "cost"
                    [ordered, order] = sort(values,'ascend');
                else
                    [ordered, order] = sort(values,'descend');
                end
                criteria = criteria(order);
                best = ordered(1);
                % Ties are only declared at machine-scale agreement. In
                % TT some criteria choose exactly the same first pipes.
                tied = abs(ordered-best) <= 1e-12*max(1,abs(best));
                row.BestRanking = join(criteria(tied),"/");
                row.BestObjectiveValue = best;
                % The absolute-value formula is meaningful here because
                % feasible incumbents prevent regression from the K=0 score.
                if objective == "cost"
                    assert(best <= initial_value + ...
                        1e-8*max(1,abs(initial_value)), ...
                        'A cost subset is worse than K=0.');
                else
                    assert(best >= initial_value - ...
                        1e-8*max(1,abs(initial_value)), ...
                        'A maximized subset is worse than K=0.');
                end
                row.ProgressPct = 100*abs(best-initial_value)/normalizer;
                if row.FeasibleRankings > 1
                    next_distinct = find(~tied,1,'first');
                    if ~isempty(next_distinct)
                        second = ordered(next_distinct);
                        row.RunnerUpRanking = criteria(next_distinct);
                        row.RunnerUpObjectiveValue = second;
                        row.RunnerUpProgressPct = ...
                            100*abs(second-initial_value)/normalizer;
                        row.LeadOverRunnerUpProgressPoints = ...
                            row.ProgressPct-row.RunnerUpProgressPct;
                        assert(isnan(row.LeadOverRunnerUpProgressPoints) || ...
                            row.LeadOverRunnerUpProgressPoints >= -1e-8, ...
                            'Runner-up progress exceeds the best ranking.');
                    end
                end
            end
            rows(end+1,1) = row; %#ok<AGROW>
        end
    end
end
all_rows = struct2table(rows);
summary_mask = false(height(all_rows),1);
for network_index = 1:numel(configs)
    cfg = configs(network_index);
    summary_mask = summary_mask | (all_rows.Network == cfg.id & ...
        ismember(all_rows.K,cfg.representative_k));
end
summary_rows = all_rows(summary_mask,:);
assert(height(summary_rows) == 6*2*numel(configs), ...
    'Representative summary has missing network/objective/K rows.');
writetable(all_rows,fullfile(output_dir, ...
    'ranked_progress_all.csv'));
writetable(summary_rows,fullfile(output_dir, ...
    'ranked_progress_representative.csv'));
fprintf('Exported %d ranked comparisons (%d representative) to %s\n', ...
    height(all_rows),height(summary_rows),output_dir);
end

function cfg = make_config(id,result_folder,full_file,key_column,total_pipes,representative_k)
cfg = struct('id',string(id),'result_folder',string(result_folder), ...
    'full_file',string(full_file),'key_column',string(key_column), ...
    'total_pipes',total_pipes,'representative_k',representative_k);
end
