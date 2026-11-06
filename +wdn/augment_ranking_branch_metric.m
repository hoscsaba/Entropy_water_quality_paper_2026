function augmented = augment_ranking_branch_metric(cfg,study,input_file)
%AUGMENT_RANKING_BRANCH_METRIC Evaluate cached designs without rerunning GA.
% The branch-hop reference weights must be fixed and shared with the new
% branch-hop objective study. Only feasible cached points enter the figure.
assert(isfield(cfg,'branch_hop_weighting'));
augmented=study;
if any(strcmp(study.metric_names,'branch_hop_weighted_entropy'))
    return;
end
st=StaciModel(input_file);
cleanup=onCleanup(@() st.release());
if strcmp(cfg.id,'anytown'), scale=0.0254; else, scale=0.001; end
ids=string(cfg.design_link_ids(:));
node_ids=string(cfg.branch_hop_weighting.node_ids(:));
branch=nan(size(study.metrics,1),size(study.metrics,2),1);
for q=1:size(branch,1)
    for j=1:size(branch,2)
        if ~(study.is_feasible(q,j) || study.k(j)==0), continue; end
        x=reshape(study.designs(q,j,:),[],1);
        st.setLinkProperty(ids,'diameter_m',x*scale);
        assert(st.solveHydraulics().converged, ...
            'Cached ranked design hydraulics failed');
        nodes=st.nodeResults();
        current=string(nodes.id(:));
        [found,wi]=ismember(current,node_ids);
        assert(all(found),'Branch-hop node mismatch');
        branch(q,j,1)=wdn.source_distance_weighted_entropy( ...
            st,cfg,cfg.branch_hop_weighting.weights(wi));
    end
end
augmented.metrics=cat(3,study.metrics,branch);
augmented.metric_names=[study.metric_names, ...
    {'branch_hop_weighted_entropy'}];
augmented.original_metrics.branch_hop_weighted_entropy=branch(1,1,1);
end
