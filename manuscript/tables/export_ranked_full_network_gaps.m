function [all_rows, summary_rows] = export_ranked_full_network_gaps(paper_root, output_dir)
%EXPORT_RANKED_FULL_NETWORK_GAPS Compare restricted designs with full designs.
% Reads the saved, current single-objective and ranked-subset CSV files; it
% performs no optimization or hydraulic calculation. For each network,
% objective and tested pipe count K, the best feasible result among the five
% fixed pipe rankings is retained. Cost is minimized; the other five
% objectives are maximized. The reported percentage gap is
%
%   cost:       100 * (C_best(K) / C_full - 1),
%   other:      100 * (1 - J_best(K) / J_full).
%
% The denominator is the saved full-network single-objective result for the
% SAME network, objective and nominal constraints. A negative gap is kept
% when a finite subset search happens to outperform the saved full search;
% neither search certifies a global optimum. Anytown K=0 is the feasible
% one-pipe-repaired initial candidate and provides a valid baseline score.
%
% The outputs are ranked_full_network_gaps_all.csv and
% ranked_full_network_gaps_representative.csv. The latter contains TT K=2,4;
% Anytown K=8,20; and Balerma K=45,90 for manuscript Section 3.4.
%
% Usage: addpath(fullfile(paper_root,'manuscript','tables'));
%        export_ranked_full_network_gaps(paper_root);

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
    'TotalPipes',NaN,'PipeFractionPct',NaN,'FullObjectiveValue',NaN, ...
    'BestRanking',"",'BestObjectiveValue',NaN,'GapToFullPct',NaN, ...
    'RunnerUpRanking',"",'RunnerUpObjectiveValue',NaN, ...
    'LeadOverRunnerUpPct',NaN,'FeasibleRankings',0);
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
        counts = sort(unique(double(ranked.K)));
        assert(all(diff(counts) > 0), 'Duplicate or unsorted K values.');
        for k = counts(:)'
            at_k = double(ranked.K) == k;
            feasible = at_k & logical(ranked.IsFeasible);
            value_column = double(ranked.(rank_column));
            feasible = feasible & isfinite(value_column);
            row = row_template;
            row.Network = cfg.id;
            row.Objective = objective;
            row.K = k;
            row.TotalPipes = cfg.total_pipes;
            row.PipeFractionPct = 100*k/cfg.total_pipes;
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
                if objective == "cost"
                    row.GapToFullPct = 100*(best/full_value - 1);
                else
                    row.GapToFullPct = 100*(1 - best/full_value);
                end
                if row.FeasibleRankings > 1
                    next_distinct = find(~tied,1,'first');
                    if ~isempty(next_distinct)
                        second = ordered(next_distinct);
                        row.RunnerUpRanking = criteria(next_distinct);
                        row.RunnerUpObjectiveValue = second;
                        if objective == "cost"
                            row.LeadOverRunnerUpPct = 100*(second/best - 1);
                        else
                            row.LeadOverRunnerUpPct = 100*(1 - second/best);
                        end
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
    'ranked_full_network_gaps_all.csv'));
writetable(summary_rows,fullfile(output_dir, ...
    'ranked_full_network_gaps_representative.csv'));
fprintf('Exported %d ranked comparisons (%d representative) to %s\n', ...
    height(all_rows),height(summary_rows),output_dir);
end

function cfg = make_config(id,result_folder,full_file,key_column,total_pipes,representative_k)
cfg = struct('id',string(id),'result_folder',string(result_folder), ...
    'full_file',string(full_file),'key_column',string(key_column), ...
    'total_pipes',total_pipes,'representative_k',representative_k);
end
