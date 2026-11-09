# Manuscript figure and table provenance

All paths are relative to this repository. The current Anytown outputs come from `networks/anytown/results_staci_anchor_replay/`; the other networks use `results_staci/`. Nominal Anytown optimization uses zero-flow R65/R165 pressure anchors; failure replay restores physical 215-ft reservoirs. The numerical solver is STACI. EPANET independently checks the final single-objective designs and supplies input/figure compatibility. See [the current computational methods](../docs/METHODS.md).

| Manuscript item | Reproduction code | Numerical input |
|---|---|---|
| Objective and performance-indicator catalogues | Companion manuscript methodology; objective implementations in `+wdn/` | Equations and run counts in the methodology; no fitted values |
| Pressure-boundary minimum example | `manuscript/figures/make_pressure_anchor_mwe_figure.m` | Analytic equations in script |
| Four-pipe flow-entropy and chlorine-entropy pairs | `manuscript/figures/make_two_consumer_entropy_example.m`; `make_two_consumer_chlorine_entropy_example.m` | `networks/y_two_consumers/input/network_original.inp`; saved pair CSVs |
| Tanyimboh–Templeman reference schematic | `manuscript/figures/make_tanyimboh_reference_schematic.m` | Published Case A values |
| Tanyimboh–Templeman node-6 reservoir equal-entropy pair (Supplementary Fig. S3) | `networks/tanyimboh_templeman/experiments/node6_reservoir/plot_node6_reservoir_pair.m`; `run_node6_reservoir_pair.m`; `check_epanet_pair.m` | `pair_result.mat`, matching INP, CSV, and EPANET check in the experiment folder; replot needs saved MAT only |
| Tanyimboh–Templeman six optimized panels | `networks/tanyimboh_templeman/run_tanyimboh_branch_hop_optimization.m`; `manuscript/figures/make_figure3.m` | Five common objectives plus `branch_hop_weighted_entropy.mat`, using frozen weights from supply entries 1 and 2 |
| Anytown schematic and pressure/chlorine matrices (main Fig. 4 and Supplementary Figs.) | `manuscript/figures/make_anytown_schematic.m`; `manuscript/figures/make_anytown_anchor_replay_figures.m` | `networks/anytown/input/network_anchor_replay.inp`, six `results_staci_anchor_replay/*.mat` designs, and `topology_branch_hop_weights.csv`; nominal pump supply with R65/R165 zero-flow anchors |
| Anytown cost–branch-hop entropy archive (Supplementary Fig.) | `networks/anytown/run_anytown_anchor_replay_pareto.m`; `wdn.plot_cost_entropy_front` | `networks/anytown/results_staci_anchor_replay/multiobjective_cost_entropy.mat` and six final MAT designs |
| Anytown cost/branch-hop and chlorine ranked-subset matrices (Supplementary Figs.) | `networks/anytown/run_anytown_anchor_replay_rankings.m` | Anytown `results_staci_anchor_replay/ranking_*_study.mat` and independent per-point cache files |
| Balerma schematic and pressure/chlorine six-panel matrices | `manuscript/figures/make_balerma_schematic.m`; `make_balerma_figures.m` | Balerma fixed-load INP, five full-network MAT designs, and `branch_hop_weighted_entropy_rank45.mat` |
| Balerma cost/branch-hop and chlorine ranked-subset matrices | `run_staci_ranking_studies.m`; `manuscript/figures/reproduce_all_figures.m` | Balerma `results_staci/ranking_*_study.mat` |
| Six-design cross-effect heat maps and trajectory-correlation table | `manuscript/tables/make_objective_relationship_summary.m`; `manuscript/figures/plot_cross_effects_portrait.m` | Released six-design CSVs, saved K=0 references, and final/ranking MAT files |
| Cross-evaluation, stress, PDA service and vulnerability tables | `networks/anytown/summarize_anytown_anchor_replay_results.m`; `run_anytown_anchor_replay_outages.m`; `summarize_anytown_anchor_replay_vulnerability.m`; `networks/balerma/refresh_balerma_branch_hop_tables.m` | Anytown nominal-anchor `results_staci_anchor_replay/*.csv` (114 equally weighted source/fault cases per design), Balerma `results_staci/*.csv` |
| Supplementary EPANET verification | `supplementary/validate_staci_final_designs.m` | Six nominal-anchor Anytown MAT designs, the other final designs, and matching INPs |

`make_anytown_anchor_replay_figures.m` replots the six current Anytown panels without a new network GA. The four-pipe chlorine script accepts `false` to replot its saved pair without a new small GA. Each current Anytown ranked-subset point is cached separately so a longer pipe-count range can resume without repeating completed points.

Portrait journal-page variants of the wide two-design and six-design figures are produced by `manuscript/figures/make_portrait_submission_figures.m` from the saved full-resolution composites. This is a visual-only operation; no hydraulic or optimization results are recomputed.

The same script slices each dense ranking matrix into six legible portrait sections (`*_cost_{a,b,c}.png` and `*_objective_{a,b,c}.png`). The Supplementary LaTeX file supplies their common 11-pt title, legend, and x-axis text. The complete matrix SVG remains available for editing; the sections are visual crops of it and retain the same numerical data.
