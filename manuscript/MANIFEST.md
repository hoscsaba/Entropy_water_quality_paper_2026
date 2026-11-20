# Publication asset manifest

This map follows the current `draft_v3/main.tex`, `supplementary_staci.tex`,
and `balerma_r38_section.tex`. Names in the first column are file basenames
under `manuscript/generated/figures/`. A single call to
`manuscript/figures/reproduce_all_figures.m` invokes the generators below
using the released results. It performs no full-network optimization or
new pipe-failure replay. Source SVGs are retained even where LaTeX includes
a PNG or PDF. The exact final result folders are listed in the root README.

| Publication asset | Generator | Saved numerical input |
|---|---|---|
| `pressure_anchor_mwe.png` | `make_pressure_anchor_mwe_figure.m` | Equations in the script |
| `entropy_loop_two_consumers.png` | `make_two_consumer_entropy_example.m`, `plot_two_consumer_pair.m` | `networks/y_two_consumers/input/network_original.inp` |
| `chlorine_entropy_loop_pair_portrait.png` | `make_two_consumer_chlorine_entropy_example(false)`, `make_portrait_submission_figures.m` | `networks/y_two_consumers/results/chlorine_entropy_pair.csv` and the same INP |
| `tanyimboh_schemtic.png`, `tanyimboh_epanet_model.png` | `make_tanyimboh_reference_schematic.m`, `make_tanyimboh_epanet_model.m` | Published directed reference flows and released TT INP |
| `figure3.png` | `make_figure3.m` | TT six final MAT designs and nominal STACI metrics |
| `tanyimboh_ranking_objectives.png`, `tanyimboh_hydraulic_todini_rankings.png`, `tanyimboh_chlorine_rankings.png` | `make_tanyimboh_ranking_matrix.m`, `make_tanyimboh_remaining_rankings.m` | TT saved K=0–8 ranking MAT studies |
| `tanyimboh_cost_branch_hop_failure_pareto.png` | `make_pareto_failure_figures.m` | TT saved Pareto archive and eight-case PDA replay per point |
| `anytown_schematic.png` | `make_anytown_schematic.m` | Anchor INP and topology-only branch-hop weights |
| `anytown_objectives_flow_3x2.png` | `make_anytown_flow_matrix.m` | Anytown six final MAT designs |
| `figure5_portrait_1.png` to `figure5_portrait_3.png` | `make_anytown_anchor_replay_figures.m`, `make_portrait_submission_figures.m` | Anytown six final MAT designs |
| `figure9_ranking_objectives.png`, `figure10_anytown_chlorine_ranking_objectives.png`, `anytown_hydraulic_todini_rankings.png` | `reproduce_all_figures.m`, `+wdn/plot_ranking_*` | Anytown saved ranking MAT studies, including refined Todini |
| `anytown_cost_branch_hop_failure_pareto.pdf` | `make_pareto_failure_figures.m` | Anytown saved Pareto archive and 114-case PDA replay per point |
| `balerma_r38_anchor_schematic.png` | `make_balerma_r38_schematic.m` | Balerma original geometry and R38 nominal boundary definition |
| `figure10_balerma_objectives_r38_anchor_3x2.png`, `figure14_balerma_chlorine_r38_anchor_3x2.png` | `make_balerma_figures.m` | Balerma R38-anchor six final MAT designs |
| `balerma_r38_anchor_pipe_diameters_only.png` | `make_balerma_pipe_only_figures.m` | `optimal_pipe_diameters_six_in.csv` and original INP geometry |
| `balerma_r38_cost_branch_rankings.png`, `balerma_r38_hydraulic_todini_rankings.png`, `balerma_r38_chlorine_rankings.png` | `reproduce_all_figures.m`, `+wdn/plot_ranking_*` | Balerma R38-anchor saved ranking MAT studies, K≤90 |
| `balerma_r38_unavailable_protected_failure_profiles.pdf` | `make_balerma_r38_unavailable_failure_profiles.m` | Balerma `r38_unavailable_protected/cases.csv`, 448 cases per design |
| `balerma_common_cost_branch_hop_failure_pareto_r38_anchor_r38_unavailable.pdf` | `make_balerma_common_pareto.m` | Balerma `pareto_r38_unavailable_study/pareto_failure_replay_r38_unavailable/pareto_failure_service.csv` |
| `steady_chlorine_trajectories.png` | `supplementary/plot_steady_chlorine_trajectories.m` | `supplementary/results/` EPANET trajectories and STACI steady values |
| `cross_effects_three_networks.png` | `plot_cross_effects_three_networks.m` | Three six-design cross-evaluation CSVs; PDF and editable SVG are also exported |

The main article and Supplementary Material include some of the same files;
these are listed once. Replotting rankings evaluates other objectives on the
**same saved diameter designs**; only the top panel in each ranking column
shows the optimized objective. `make_portrait_submission_figures.m` crops the
two listed SM layouts for readable portrait pages. Its source PNG and SVG
composites remain available for editing.

Nominal cross-evaluation and failure-service tables are exported from saved
CSVs by `manuscript/tables/export_manuscript_tables.m` and the network-specific
`export_*_sm_data.m` / `supplementary/build_balerma_r38_sm_tables.py`
procedures. Their numerical provenance is described alongside each table in
the Supplementary Material. TT's direct EPANET comparisons live in
`supplementary/results/validation_tt_10_120_clsplit_v2/`, Anytown's in
`supplementary/results/validation_anytown_10_120_clsplit_final/`, and
Balerma's in its final result directory under `epanet_validation/`.
The separate Balerma comparison in Supplementary Section 2 uses the
four-source, 10–500 mm archive `networks/balerma/results_staci/` and its
saved validation CSV. It is an earlier solver benchmark, not a current
diameter-design result.
