function reproduce_all_figures(staci_root,mex_dir)
%REPRODUCE_ALL_FIGURES Regenerate article and supplementary figures.
%   Uses saved design vectors, rankings, and pipe-failure results. It does
%   not rerun the network searches or failure cases. The four-pipe examples
%   solve their nominal hydraulics from the network input.
%
%   See manuscript/MANIFEST.md for each figure's numerical source. Build
%   STACI's MATLAB MEX interface before calling this function.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin<1 || isempty(staci_root)
    error('Pass the absolute path to the STACI checkout.');
end
if nargin<2 || isempty(mex_dir)
    mex_dir=fullfile(staci_root,'build-matlab','Matlab');
end
addpath(root,fullfile(root,'manuscript','figures'), ...
    fullfile(root,'supplementary'),fullfile(staci_root,'matlab'), ...
    mex_dir,'-begin');
generated=fullfile(root,'manuscript','generated','figures');
if ~isfolder(generated),mkdir(generated);end

% Analytical and small-network illustrations.
make_pressure_anchor_mwe_figure;
make_two_consumer_entropy_example;
make_tanyimboh_reference_schematic;
make_tanyimboh_epanet_model;

% TT: six saved designs, three ranked-subset comparisons, and Pareto replay.
make_figure3;
make_tanyimboh_ranking_matrix(root);
make_tanyimboh_remaining_rankings(root);

% Anytown: nominal maps, ranked subsets and saved Pareto replay.
make_anytown_schematic;
make_anytown_flow_matrix(root);
make_anytown_anchor_replay_figures;
anytown_figures=fullfile(root,'networks','anytown', ...
    'figures_staci_anchor_replay');
copy_art(fullfile(anytown_figures,'figure5.png'),generated);
replot_anytown_rankings(root,generated);
make_pareto_failure_figures(root,generated);

% Balerma: R38 is the nominal zero-flow anchor. The displayed failure
% profiles and Pareto colors use the separate R38-unavailable PDA replay.
balerma_dir=fullfile(root,'networks','balerma');
results=fullfile(balerma_dir, ...
    'results_staci_r38_anchor_r44_physical_0p1_64in_v1');
local_figures=fullfile(balerma_dir,'figures_staci_r38_anchor_v1');
copy_art(make_balerma_r38_schematic(root,local_figures),generated);
make_balerma_figures;
make_balerma_pipe_only_figures;
replot_balerma_rankings(root,results,local_figures,generated);
copy_art(make_balerma_r38_unavailable_failure_profiles( ...
    root,results,local_figures),generated);
copy_art(make_balerma_common_pareto(root, ...
    fullfile(results,'pareto_r38_unavailable_study'),local_figures, ...
    'r38_anchor_r38_unavailable'),generated);

% S1 compares saved EPANET time histories with stationary STACI values.
plot_steady_chlorine_trajectories( ...
    fullfile(root,'supplementary','results','current_chlorine'), ...
    fullfile(root,'supplementary','results'));
copy_art(fullfile(root,'supplementary','results', ...
    'steady_chlorine_trajectories.png'),generated);
copy_art(fullfile(root,'supplementary','results', ...
    'steady_chlorine_trajectories.svg'),generated);
make_portrait_submission_figures;
fprintf('Figures written to %s\n',generated);
end

function replot_anytown_rankings(root,generated)
network_dir=fullfile(root,'networks','anytown');
addpath(network_dir,'-begin');
cfg=network_config_anchor_replay(network_dir);
folder=cfg.results_dir;
a=load(fullfile(folder,'ranking_cost_study.mat'),'study');
b=load(fullfile(folder, ...
    'ranking_branch_hop_weighted_entropy_study.mat'),'study');
copy_art(wdn.plot_ranking_objective_matrix( ...
    cfg,a.study,b.study,struct()),generated);
copy_art(wdn.plot_ranking_objective_matrix( ...
    cfg,a.study,b.study,struct(),"optimized_only"),generated);
a=load(fullfile(folder,'ranking_chlorine_concentration_study.mat'),'study');
b=load(fullfile(folder,'ranking_chlorine_entropy_study.mat'),'study');
copy_art(wdn.plot_ranking_chlorine_matrix(cfg,a.study,b.study),generated);
a=load(fullfile(folder,'ranking_hydraulic_entropy_study.mat'),'study');
b=load(fullfile(folder,'ranking_todini_refined_study.mat'),'refined');
copy_art(wdn.plot_ranking_pair_matrix(cfg,a.study,b.refined, ...
    'anytown_hydraulic_todini_rankings'),generated);
end

function replot_balerma_rankings(root,results,local_figures,generated)
network_dir=fullfile(root,'networks','balerma');
addpath(network_dir,'-begin');
cfg=network_config_r38_anchor(network_dir);
cfg.results_dir=results;
cfg.figures_dir=local_figures;
a=load(fullfile(results,'ranking_cost_branch_hop_study.mat'), ...
    'cost_branch_study');
b=load(fullfile(results,'ranking_branch_hop_study.mat'),'branch_study');
copy_art(wdn.plot_ranking_objective_matrix( ...
    cfg,a.cost_branch_study,b.branch_study,struct()),generated);
a=load(fullfile(results,'ranking_entropy_study.mat'),'entropy_study');
b=load(fullfile(results,'ranking_todini_study.mat'),'todini_study');
copy_art(wdn.plot_ranking_pair_matrix(cfg, ...
    a.entropy_study,b.todini_study, ...
    'balerma_r38_hydraulic_todini_rankings'),generated);
a=load(fullfile(results,'ranking_chlorine_concentration_study.mat'), ...
    'concentration_study');
b=load(fullfile(results,'ranking_chlorine_entropy_study.mat'), ...
    'entropy_study');
copy_art(wdn.plot_ranking_chlorine_matrix(cfg, ...
    a.concentration_study,b.entropy_study),generated);
end

function copy_art(files,generated)
% Plotters return either one file or a cell array of PNG/SVG/PDF files.
if ischar(files) || isstring(files),files=cellstr(files);end
for k=1:numel(files)
    source=char(files{k});
    assert(isfile(source),'Figure generator did not create %s',source);
    [~,name,ext]=fileparts(source);
    copyfile(source,fullfile(generated,[name ext]),'f');
    if strcmpi(ext,'.png')
        svg=fullfile(fileparts(source),[name '.svg']);
        if isfile(svg),copyfile(svg,fullfile(generated,[name '.svg']),'f');end
    end
end
end
