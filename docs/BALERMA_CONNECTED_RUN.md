# Balerma four-reservoir recalculation

The benchmark introduced by Reca and Martínez (2006, doi:10.1029/2005WR004383) is a four-source network. The preserved `network_original.inp` contains reservoirs 38, 43, 44, and 88 and no pump entries; the literature does not designate a sole primary source. The one-source/three-anchor alternative is therefore not used in this reproduction.

The Balerma fixed-load input contains four physical fixed-head reservoirs:
38 (117 m), 43 (127 m), 44 (122 m), and 88 (112 m). All remain present in
nominal optimization and single-pipe failure replay. Reservoir flow may be
positive or negative as dictated by hydraulics. No zero-flow pressure anchor
is substituted. A pipe failure can physically isolate an island; the outage
solver retains every component containing any of the four reservoirs and
records zero service for components without a source.

The staged calculation keeps the previous published files intact until the
new results pass hydraulic, chlorine, and EPANET checks. Run from the paper
repository root in MATLAB after `startup`, with `staci_root` and `mex_dir`
pointing to the STACI checkout and compiled MEX directory:

```matlab
paper_root = pwd;
addpath(fullfile(paper_root,'networks','balerma'))
run_balerma_connected_full(paper_root,staci_root,mex_dir)
finalize_balerma_connected_full(paper_root,staci_root,mex_dir)
run_staci_ranking_studies(staci_root,mex_dir,'balerma', ...
    {'cost','branch_hop_weighted_entropy', ...
     'chlorine_concentration','chlorine_entropy'}, ...
    fullfile(paper_root,'networks','balerma','results_staci_connected'), ...
    fullfile(paper_root,'networks','balerma','figures_staci_connected'))
run_staci_outage_studies(staci_root,mex_dir,{'balerma'}, ...
    fullfile(paper_root,'networks','balerma','results_staci_connected'))
refresh_balerma_branch_hop_tables(paper_root,staci_root,mex_dir, ...
    fullfile(paper_root,'networks','balerma','results_staci_connected'))
run_pda_vulnerability_analysis('results_staci_connected',{'balerma'})
make_balerma_figures( ...
    fullfile(paper_root,'networks','balerma','results_staci_connected'), ...
    fullfile(paper_root,'networks','balerma','figures_staci_connected'))
```

The four-source branch-hop weight is the frozen undirected topological
`1/(1+b)` measure from all four reservoirs. `balerma_connected_branch_weights.m`
constructs it without a hydraulic run. The five full-network GAs retain
the published 100-member population, 150-stall-generation condition,
10,000-generation ceiling, and two-hour per-objective safeguard. The ranked
study retains `K=0,5,20,45`, five ranking criteria, 100-member population,
100-generation ceiling, and 30-stall-generation condition. Each ranked point
has an independent cache entry for resumption. Candidate evaluations use a
resident STACI model and do not write per-candidate INP or quality files.
