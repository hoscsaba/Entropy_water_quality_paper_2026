# Reproducing the STACI calculations

## Required software

Use MATLAB R2026a with Optimization Toolbox and Global Optimization Toolbox, the MATLAB MEX interface from the [STACI repository](https://github.com/hoscsaba/staci), and EPANET 2.2 with the EPANET-MATLAB Toolkit for the independent verification only. The paper code keeps one `StaciModel` in memory during each genetic search; a candidate changes its pipe diameters, solves hydraulics, and, when needed, solves stationary chlorine. It does not write a new INP per candidate.

The shared settings and exact seed vectors are versioned in `networks/<network>/network_config.m` and `networks/<network>/seeds/`. The current final GA runner allows up to 10,000 generations in all three networks, allows 150 stall generations, and applies a two-hour wall-time safeguard per objective. The archived Balerma searches began with a 2,000-generation ceiling and continued when that ceiling was reached; their exact stopping audit is in the supplementary material. The saved MAT files, not the generation ceilings, record actual stopping generations and reasons. One MATLAB search uses one worker; the source model is mutable.

## Reproduction sequence

From the paper repository root, define the absolute paths to a STACI checkout and a directory containing `staci_mex`, then run:

```matlab
startup
staci_root = '/absolute/path/to/staci';
mex_dir = '/absolute/path/to/staci/matlab';
addpath(fullfile(staci_root,'matlab'),mex_dir)
assert(exist('staci_mex','file') == 3)
run_staci_all_optimizations(staci_root,mex_dir)
continue_balerma_hydraulic_entropy(staci_root,mex_dir)
continue_balerma_capped_objective(staci_root,mex_dir,'chlorine_entropy',600)
continue_balerma_capped_objective(staci_root,mex_dir,'todini',840)
finalize_balerma_cross_elites(staci_root,mex_dir)
select_staci_best_feasible_incumbents(staci_root,mex_dir,'balerma')
finalize_staci_single_objectives(staci_root,mex_dir)
addpath('supplementary')
validate_staci_final_designs(staci_root,mex_dir)
run_staci_outage_studies(staci_root,mex_dir)
verify_balerma_island_handling(staci_root,mex_dir) % after addpath('supplementary')
run_pda_vulnerability_analysis('results_staci')
run_staci_ranking_studies(staci_root,mex_dir,'anytown')
run_staci_ranking_studies(staci_root,mex_dir,'balerma')
run_staci_cost_entropy_front(staci_root,mex_dir)
addpath('manuscript/figures','manuscript/tables')
reproduce_all_figures(staci_root,mex_dir)
export_manuscript_tables
```

Completed final MAT files and ranked-subset cache entries are reused. To rerun a final objective, pass its network and objective to `run_staci_all_optimizations` with the final `rerun_existing` flag set to `true`, or move that one MAT file out of `results_staci/`. Every ranked-subset cache entry is keyed by objective, ranking criterion, and number of free pipes; extending the range preserves completed entries. The initial Anytown network violates the zero-flow pressure-anchor head bands. The versioned feasible interpolation and saved incumbent seeds are therefore part of the reproducible search setup.
The three explicit Balerma continuation calls above replay the archived staged search and reuse the saved continuation MAT files. A fresh 10,000-generation run already uses the two-hour stop and does not require those additional continuations.

The five STACI single-objective runs for each of the three networks are the final designs. The independent EPANET replay applies each full-precision diameter vector to the identical fixed-load INP, runs hydraulics, and advances first-order chlorine for 14 days. The comparison CSV reports maximum and mean absolute differences over matching node IDs for total head and chlorine, and over matching link IDs for signed flow. It also reports Anytown anchor-head deviations and minimum residual at material-demand consumers. EPANET does not supply any reported optimizer fitness or constraint value.

## Interpretation and provenance

`results_staci/` contains the final designs, objective cross-evaluations, baseline states, outage statistics, ranking studies, and Pareto archive. The saved MAT files include diameter order, exact diameters, all five metrics, constraint violations, GA status, random seed, and elapsed time. The article and Supplementary Material use the accompanying CSV exports. Diameter rounding can matter near the 0.5-ft Anytown pressure-anchor limit, so verify the exact saved vector.

The Tanyimboh--Templeman reference flow table is a separate analytical check, reproduced by `wdn.verify_tanyimboh_reference` using constrained flow optimization without pipe diameters. The figure examples use STACI and are documented in the repository README. A finite genetic search, even after MATLAB's function-tolerance stop, supplies a best-known feasible design rather than a proof of global optimality.
