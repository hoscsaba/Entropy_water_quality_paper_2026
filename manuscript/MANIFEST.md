# Manuscript figure and table provenance

All paths are relative to this repository. Reported network outputs come from `results_staci/`; the numerical solver is STACI. EPANET is used only for the independent 15-design comparison in `supplementary/` and for input/figure compatibility.

| Manuscript item | Reproduction code | Numerical input |
|---|---|---|
| Pressure-boundary minimum example | `manuscript/figures/make_pressure_anchor_mwe_figure.m` | Analytic equations in script |
| Four-pipe flow-entropy and chlorine-entropy pairs | `manuscript/figures/make_two_consumer_entropy_example.m`; `make_two_consumer_chlorine_entropy_example.m` | `networks/y_two_consumers/input/network_original.inp`; saved pair CSVs |
| Tanyimboh–Templeman reference schematic | `manuscript/figures/make_tanyimboh_reference_schematic.m` | Published Case A values |
| Tanyimboh–Templeman six-panel matrix | `manuscript/figures/make_figure3.m` | `networks/tanyimboh_templeman/results_staci/*.mat` |
| Anytown schematic and pressure/chlorine matrices | `manuscript/figures/make_anytown_schematic.m`; `make_anytown_figures.m` | Anytown fixed-load INP and `results_staci/*.mat` |
| Anytown cost–hydraulic-entropy archive | `run_staci_cost_entropy_front.m`; `wdn.plot_cost_entropy_front` | `networks/anytown/results_staci/multiobjective_cost_entropy.mat` |
| Anytown hydraulic/chlorine ranked-subset matrices | `run_staci_ranking_studies.m`; `manuscript/figures/reproduce_all_figures.m` | Anytown `results_staci/ranking_*_study.mat` |
| Balerma schematic and six-panel matrix | `manuscript/figures/make_balerma_schematic.m`; `make_balerma_figures.m` | Balerma fixed-load INP and `results_staci/*.mat` |
| Balerma hydraulic/chlorine ranked-subset matrices | `run_staci_ranking_studies.m`; `manuscript/figures/reproduce_all_figures.m` | Balerma `results_staci/ranking_*_study.mat` |
| Cross-effect heat map and trajectory-correlation table | `manuscript/tables/make_objective_relationship_summary.m` | Anytown and Balerma STACI final/ranking MAT files |
| Cross-evaluation, N−1 stress, PDA service and vulnerability tables | `finalize_staci_single_objectives.m`; `run_staci_outage_studies.m`; `run_pda_vulnerability_analysis.m` | Network `results_staci/*.csv` |
| Supplementary EPANET verification | `supplementary/validate_staci_final_designs.m` | 15 STACI final designs plus fixed-load INPs |

`manuscript/figures/reproduce_all_figures.m` replots saved results without a new network GA. The four-pipe chlorine script accepts `false` to replot its saved pair without a new small GA. Each `run_staci_ranking_studies.m` point is cached separately so a longer pipe-count range can resume without repeating completed points.
