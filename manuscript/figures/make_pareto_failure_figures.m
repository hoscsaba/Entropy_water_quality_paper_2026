function make_pareto_failure_figures(paper_root,generated_dir)
%MAKE_PARETO_FAILURE_FIGURES Render the two fully replayed Pareto archives.
% The six single-objective service tables are not used to color individual
% Pareto points: every point has its own PDA pipe-failure replay CSV row.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2 || isempty(generated_dir)
    generated_dir=fullfile(paper_root,'manuscript','generated','figures');
end
addpath(paper_root);
entries={ ...
    'tanyimboh_templeman','pareto_cost_branch_hop.mat','result', ...
        'results_staci_10_120_clsplit_v2', ...
        'figures_staci_10_120_clsplit_v2', ...
        'tanyimboh_cost_branch_hop_failure_pareto.png'; ...
    'anytown','pareto_plot_archive.mat','plot_result', ...
        'results_staci_anchor_replay','figures_staci_anchor_replay', ...
        'anytown_cost_branch_hop_failure_pareto.png'};
for k=1:size(entries,1)
    network_dir=fullfile(paper_root,'networks',entries{k,1});
    result_dir=fullfile(network_dir,entries{k,4});
    saved=load(fullfile(result_dir,entries{k,2}),entries{k,3});
    archive=saved.(entries{k,3});
    service=readtable(fullfile(result_dir,'pareto_failure_replay', ...
        'pareto_failure_service.csv'));
    output_file=fullfile(network_dir,entries{k,5},entries{k,6});
    % Both Supplementary figures display about 20 saved points at uniform
    % normalized-objective arclength. Color and circle size encode each
    % point's own PDA replay; no hydraulics is rerun for rendering.
    style="tt_inverse_cl";
    wdn.plot_pareto_failure_service(archive,service,output_file,style);
    if ~isfolder(generated_dir),mkdir(generated_dir);end
    [~,name]=fileparts(output_file);
    copyfile(output_file,fullfile(generated_dir,[name '.png']),'f');
    copyfile(fullfile(fileparts(output_file),[name '.svg']), ...
        fullfile(generated_dir,[name '.svg']),'f');
    copyfile(fullfile(fileparts(output_file),[name '.pdf']), ...
        fullfile(generated_dir,[name '.pdf']),'f');
end
end
