function output_file=repair_balerma_r38_todini_seed( ...
        paper_root,staci_root,mex_dir)
%REPAIR_BALERMA_R38_TODINI_SEED Add numerical chlorine reserve at node 212.
% EPANET gave 0.19993 mg/L at node 212 for a STACI-feasible Todini GA
% candidate. The consumer is supplied through P257. Test small reductions
% in P257 diameter, which shorten residence time, and retain the best
% candidate satisfying the common pressure, anchor, and guarded 0.2 mg/L
% chlorine constraints. Final GA and EPANET validation are still required.
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
source=fullfile(cfg.results_dir,'refined_ga','todini.mat');
assert(isfile(source),'Refined Todini GA result is required');
saved=load(source,'result');
x0=double(saved.result.design_diameters(:)');
[found,i]=ismember("257",string(cfg.design_link_ids(:)));
assert(found);
st=StaciModel(cfg.inp_file);
release=onCleanup(@()st.release()); %#ok<NASGU>
[links,original]=wdn.staci_input_link_template(cfg.inp_file,st,0.001);
best_score=-inf;
best_x=[];
best_metrics=[];
steps=[0.5,1,2,3,5,10,20,30,50];
for step=steps
    x=x0;
    x(i)=max(cfg.minimum_diameter,x0(i)-step);
    [metrics,violation]=wdn.evaluate_staci_design( ...
        st,cfg,x,links,original);
    fprintf('P257 -%.1f mm: minCl %.8f, Todini %.9f, violation %.4g\n', ...
        step,metrics.minimum_consumer_chlorine_mgL, ...
        metrics.todini,violation);
    if violation<=cfg.ga.constraint_tolerance && ...
            metrics.todini>best_score
        best_score=metrics.todini;
        best_x=x;
        best_metrics=metrics;
    end
end
assert(~isempty(best_x), ...
    'No P257 correction satisfies the guarded chlorine constraint');
output_file=fullfile(cfg.results_dir,'feasible_populations', ...
    'todini_repaired_seed.mat');
save(output_file,'best_x','best_metrics','best_score','steps','-v7');
fprintf('Repaired Todini seed: P257 %.3f mm, minCl %.8f, Todini %.9f\n', ...
    best_x(i),best_metrics.minimum_consumer_chlorine_mgL,best_score);
end
