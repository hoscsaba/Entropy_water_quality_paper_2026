function make_tanyimboh_ranking_matrix(paper_root,draft_figures_dir)
%MAKE_TANYIMBOH_RANKING_MATRIX Plot saved TT ranked-subset studies.
% Two columns compare cost and branch-hop optimized designs. The five
% lower rows in each column evaluate other objectives on the SAME designs.
% This reads completed K=0:8 searches and performs no hydraulic simulation.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
addpath(paper_root,'-begin');
network_dir=fullfile(paper_root,'networks','tanyimboh_templeman');
addpath(network_dir,'-begin');
cfg=network_config(network_dir);
cfg.results_dir=fullfile(network_dir,'results_staci_10_120_clsplit_v2');
cfg.figures_dir=fullfile(network_dir,'figures_staci_10_120_clsplit_v2');
cfg.ranking.figure_basename='tanyimboh_ranking_objectives';

a=load(fullfile(cfg.results_dir,'ranking_cost_branch_hop_study.mat'), ...
    'cost_branch_study');
b=load(fullfile(cfg.results_dir,'ranking_branch_hop_study.mat'), ...
    'branch_study');
assert(isequal(double(a.cost_branch_study.k(:)'),0:8) && ...
    isequal(double(b.branch_study.k(:)'),0:8), ...
    'The TT ranking plot requires every saved subset size K=0,...,8.');
files=wdn.plot_ranking_objective_matrix(cfg, ...
    a.cost_branch_study,b.branch_study,struct());

generated=fullfile(paper_root,'manuscript','generated','figures');
if ~isfolder(generated),mkdir(generated);end
for k=1:numel(files)
    [~,name,ext]=fileparts(files{k});
    copyfile(files{k},fullfile(generated,[name ext]),'f');
    if nargin>=2 && ~isempty(draft_figures_dir)
        if ~isfolder(draft_figures_dir),mkdir(draft_figures_dir);end
        copyfile(files{k},fullfile(draft_figures_dir,[name ext]),'f');
    end
end
end
