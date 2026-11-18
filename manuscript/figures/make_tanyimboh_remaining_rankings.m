function make_tanyimboh_remaining_rankings(paper_root,draft_figures_dir)
%MAKE_TANYIMBOH_REMAINING_RANKINGS Render the other four TT objectives.
% Pair 1: hydraulic entropy and Todini; pair 2: chlorine concentration
% and chlorine entropy. Saved K=0:8 MAT studies are the only numeric input.
% No optimization or STACI simulation is performed here.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
addpath(paper_root,'-begin');
network_dir=fullfile(paper_root,'networks','tanyimboh_templeman');
addpath(network_dir,'-begin');
cfg=network_config(network_dir);
cfg.results_dir=fullfile(network_dir,'results_staci_10_120_clsplit_v2');
cfg.figures_dir=fullfile(network_dir,'figures_staci_10_120_clsplit_v2');

a=load(fullfile(cfg.results_dir,'ranking_entropy_study.mat'),'entropy_study');
b=load(fullfile(cfg.results_dir,'ranking_todini_study.mat'),'todini_study');
c=load(fullfile(cfg.results_dir,'ranking_chlorine_concentration_study.mat'), ...
    'concentration_study');
d=load(fullfile(cfg.results_dir,'ranking_chlorine_entropy_study.mat'), ...
    'entropy_study');
pairs = { ...
    a.entropy_study,b.todini_study,'tanyimboh_hydraulic_todini_rankings'; ...
    c.concentration_study,d.entropy_study,'tanyimboh_chlorine_rankings'};
generated=fullfile(paper_root,'manuscript','generated','figures');
if ~isfolder(generated),mkdir(generated);end
for p=1:size(pairs,1)
    files=wdn.plot_ranking_pair_matrix(cfg,pairs{p,1},pairs{p,2},pairs{p,3});
    for k=1:numel(files)
        [~,name,ext]=fileparts(files{k});
        copyfile(files{k},fullfile(generated,[name ext]),'f');
        if nargin>=2 && ~isempty(draft_figures_dir)
            if ~isfolder(draft_figures_dir),mkdir(draft_figures_dir);end
            copyfile(files{k},fullfile(draft_figures_dir,[name ext]),'f');
        end
    end
end
end
