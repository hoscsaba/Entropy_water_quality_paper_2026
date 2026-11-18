function make_tanyimboh_submission_panels(paper_root,draft_figures_dir)
%MAKE_TANYIMBOH_SUBMISSION_PANELS Copy the single saved-data TT matrix.
% The historical function name is retained for existing reproduction calls.
% It performs no hydraulic, quality, or optimization calculation.
source=fullfile(paper_root,'manuscript','generated','figures');
if ~isfolder(draft_figures_dir),mkdir(draft_figures_dir);end
copyfile(fullfile(source,'figure3.png'), ...
    fullfile(draft_figures_dir,'figure3.png'),'f');
copyfile(fullfile(source,'figure3.svg'), ...
    fullfile(draft_figures_dir,'figure3.svg'),'f');
end
