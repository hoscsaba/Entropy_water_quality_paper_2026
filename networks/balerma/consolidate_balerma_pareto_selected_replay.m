function summary=consolidate_balerma_pareto_selected_replay(result_dir)
%CONSOLIDATE_BALERMA_PARETO_SELECTED_REPLAY Collect selected PDA checkpoints.
% Does not run hydraulics or chlorine. All selected point indices must have
% 908 converged outage cases, and their saved diameters must match the
% corrected nominal candidate archive exactly.
saved=load(fullfile(result_dir,'pareto_cost_branch_hop_top90.mat'),'result');
designs=double(saved.result.designs);
selected=readtable(fullfile(result_dir,'pareto_selected20_indices.csv'));
ids=double(selected.ArchiveIndex(:));
assert(numel(unique(ids))==numel(ids) && ...
    all(ids>=1 & ids<=size(designs,1)));
rows=cell(numel(ids),1);
for k=1:numel(ids)
    checkpoint=fullfile(result_dir,'pareto_failure_replay_r44', ...
        'checkpoints',sprintf('point_%04d.mat',ids(k)));
    item=load(checkpoint,'row','all_cases','diameters');
    assert(isequal(double(item.diameters(:)'),designs(ids(k),:)) && ...
        item.row.ArchiveIndex==ids(k) && ...
        item.row.FailureCases==908 && ...
        item.row.NonconvergentScenarios==0 && ...
        height(item.all_cases)==908, ...
        'Incomplete or stale Balerma Pareto replay checkpoint %d',ids(k));
    rows{k}=item.row;
end
summary=sortrows(vertcat(rows{:}),'ArchiveIndex');
writetable(summary,fullfile(result_dir, ...
    'pareto_failure_replay_r44','pareto_failure_service.csv'));
fprintf('Balerma: consolidated %d selected R44 replay points\n', ...
    height(summary));
end
