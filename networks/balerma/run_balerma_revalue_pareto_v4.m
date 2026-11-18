function result=run_balerma_revalue_pareto_v4( ...
        paper_root,staci_root,mex_dir,result_dir,candidate_file)
%RUN_BALERMA_REVALUE_PARETO_V4 Re-evaluate a saved 90-pipe candidate pool.
% The archived diameter vectors are feasible under the common nominal
% constraints. Only their diameter vectors are used: all six objectives and
% constraints are recalculated with all four reservoirs as zero-hop supply
% roots. The corrected K=90 cost and branch-hop ranked endpoints are added.
% This yields a finite trade-off sample, not a new multiobjective GA or a
% proof that the nondominated sample is the global Pareto frontier.
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
if nargin<4 || isempty(result_dir)
    result_dir=fullfile(network_dir, ...
        'results_staci_uniform_0p1_64in_sourceentry_v4');
end
if nargin<5 || isempty(candidate_file)
    candidate_file=fullfile(result_dir,'pareto_candidate_pool_pre_v4.mat');
end
cfg=network_config(network_dir);
cfg.branch_hop_weighting=balerma_connected_branch_weights(cfg);
source=load(candidate_file,'result');
assert(strcmp(source.result.constraint_set_id,cfg.constraint_set_id) && ...
    source.result.optimized_pipe_count==90 && ...
    size(source.result.designs,2)==454, ...
    'The saved Balerma candidate pool has a different design space');
designs=double(source.result.designs);
source_candidate_count=size(designs,1);
for objective={'cost','branch_hop_weighted_entropy'}
    item=load(fullfile(result_dir,'ranking_cache',objective{1}, ...
        'volume','k_090.mat'),'entry');
    assert(item.entry.is_feasible, ...
        'A corrected Balerma K=90 endpoint is infeasible');
    designs(end+1,:)=double(item.entry.design_diameters(:)'); %#ok<AGROW>
end
designs=unique(designs,'rows','stable');
n=size(designs,1);
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
st=StaciModel(input_file);
release=onCleanup(@()st.release());
[link_order,original_full]=wdn.staci_input_link_template( ...
    input_file,st,0.001);
result=source.result;
result.designs=designs;
for field={'cost','branch_hop_entropy','hydraulic_entropy', ...
        'chlorine_concentration','chlorine_entropy','todini', ...
        'max_constraint_violation'}
    result.(field{1})=zeros(n,1);
end
started=tic;
for i=1:n
    [m,v]=wdn.evaluate_staci_design( ...
        st,cfg,designs(i,:),link_order,original_full);
    result.cost(i)=m.cost;
    result.branch_hop_entropy(i)=m.branch_hop_weighted_entropy;
    result.hydraulic_entropy(i)=m.hydraulic_entropy;
    result.chlorine_concentration(i)=m.chlorine_concentration;
    result.chlorine_entropy(i)=m.chlorine_entropy;
    result.todini(i)=m.todini;
    result.max_constraint_violation(i)=v;
end
assert(all(result.max_constraint_violation<=cfg.ga.constraint_tolerance), ...
    'The re-evaluated Pareto candidate pool contains an infeasible design');
result.optimizer_values=[result.cost(:)/1e6, ...
    -result.branch_hop_entropy(:)];
result.branch_hop_weighting_version=cfg.branch_hop_weighting.version;
result.source_candidate_count=source_candidate_count;
result.archive_provenance= ...
    'Earlier feasible fixed-top-90 diameter candidates re-evaluated with v4 weights; corrected cost and branch-hop K=90 endpoints added; no fresh multiobjective GA';
result.output=struct('method','candidate_revaluation', ...
    'candidate_count',n);
result.exitflag=NaN;
result.elapsed_time_seconds=toc(started);
save(fullfile(result_dir,'pareto_cost_branch_hop_top90.mat'), ...
    'result','-v7');
fprintf('Balerma corrected finite trade-off: %d designs (%d archived), %.1f s\n', ...
    n,source_candidate_count,result.elapsed_time_seconds);
clear release st
end
