function run_balerma_connected_full(paper_root,staci_root,mex_dir)
%RUN_BALERMA_CONNECTED_FULL Fresh five-objective GA with four reservoirs.
% Four physical reservoirs (38/43/44/88) remain connected in nominal and
% outage states; none is replaced by a zero-flow anchor. The five new GAs
% write to a staging directory for review. Canonical final vectors are used
% only as warm starts. Each candidate uses one resident STACI MEX model;
% this procedure does not run EPANET or publish staged results.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','balerma');
addpath(network_dir);
cfg=network_config(network_dir);
assert(isequal(sort(string(cfg.source_node_ids(:))), ...
    sort(["38";"43";"44";"88"])), ...
    'Expected all four physical Balerma reservoirs');
assert(~isfield(cfg,'pressure_anchor_node_ids'), ...
    'Balerma must not use pressure-anchor substitution');
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
content=fileread(input_file);
reservoir_block=regexp(content, ...
    '(?s)\[RESERVOIRS\](.*?)\[TANKS\]','tokens','once');
assert(~isempty(reservoir_block),'Balerma fixed-load reservoirs missing');
for id=string(cfg.source_node_ids(:))'
    assert(~isempty(regexp(reservoir_block{1}, ...
        ['(?m)^\s*' char(id) '\s+'], 'once')), ...
        'Reservoir %s missing from fixed-load INP',id);
end
cfg.results_dir=fullfile(network_dir,'results_staci_connected');
cfg.figures_dir=fullfile(network_dir,'figures_staci_connected');
if ~isfolder(cfg.results_dir),mkdir(cfg.results_dir);end
cfg.ga.display='final';
cfg.ga.max_generations=10000;
cfg.ga.max_stall_generations=max(150,cfg.ga.max_stall_generations);
cfg.ga.maximum_wall_seconds=7200;
cfg.ga.use_hybrid_patternsearch=false;
run_id='balerma_four_connected_reservoirs_v1';
old_dir=fullfile(network_dir,'results_staci');
for objective=string(cfg.objectives)
    target=fullfile(cfg.results_dir,objective+'.mat');
    if ~isfile(target)
        source=fullfile(old_dir,objective+'.mat');
        if isfile(source),copyfile(source,target);end
    end
end
for objective=string(cfg.objectives)
    target=fullfile(cfg.results_dir,objective+'.mat');
    if isfile(target)
        old=load(target,'result');
        if isfield(old.result,'connected_recalculation_id') && ...
                strcmp(old.result.connected_recalculation_id,run_id)
            fprintf('SKIP Balerma/%s: completed connected-reservoir GA\n', ...
                objective);
            continue
        end
    end
    fprintf('START Balerma/%s with four connected reservoirs at %s\n', ...
        objective,datetime('now'));
    wdn.optimize_staci_single_objective(cfg,char(objective), ...
        input_file,target);
    saved=load(target,'result');
    result=saved.result;
    result.connected_recalculation_id=run_id;
    result.connected_reservoir_ids=cfg.source_node_ids;
    save(target,'result','-v7');
    fprintf('DONE Balerma/%s: %d generations, %.1f s, violation %.6g\n', ...
        objective,result.ga_last_generation, ...
        result.elapsed_time_seconds,result.max_constraint_violation);
end
end
