function result_dir=finalize_balerma_r38_sm(paper_root,staci_root,mex_dir)
%FINALIZE_BALERMA_R38_SM Select, validate, replay, and plot saved designs.
% Run after the six nominal and ranked-subset searches and any optional
% full-network GA refinements. No search is started here. All candidate
% designs are checked afresh against the common nominal constraints before
% selection; EPANET independently checks each selected nominal vector.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2 || isempty(staci_root)
    staci_root='/Users/hoscsaba/Documents/GitHub/staci';
end
if nargin<3 || isempty(mex_dir)
    mex_dir=fullfile(staci_root,'build-matlab','Matlab');
end
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(paper_root,'manuscript','figures'), ...
    fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
result_dir=cfg.results_dir;
adopt_balerma_r38_refined_designs(paper_root,staci_root,mex_dir);
run_balerma_r38_anchor(paper_root,staci_root,mex_dir,'audit');
run_balerma_r38_anchor(paper_root,staci_root,mex_dir,'validate');
run_balerma_r38_anchor(paper_root,staci_root,mex_dir,'replay');
figure_dir=fullfile(network_dir,'figures_staci_r38_anchor_v1');
make_balerma_r38_schematic(paper_root,figure_dir);
make_balerma_figures(result_dir,figure_dir);
make_balerma_pipe_only_figures(figure_dir,result_dir);
make_balerma_r38_failure_profiles(paper_root,result_dir,figure_dir);
make_balerma_common_pareto(paper_root,result_dir,figure_dir, ...
    'r38_anchor_protected_all_four');
fprintf('Final R38-anchor results and figures: %s\n',result_dir);
end
