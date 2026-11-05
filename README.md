# Entropy and water quality in distribution networks: computation archive

This repository accompanies the manuscript *Entropy-Based Pipe Sizing in Water Distribution Networks: Boundary Effects, Water Quality, and Failure Performance*. The reported fixed-load network objectives, final pipe designs, rankings, Pareto archive, and single-pipe outage tests are calculated with **STACI** through MATLAB. **EPANET 2.2 is used independently to verify the 15 final single-objective designs**, using the same INP and saved full-precision diameters. The supplementary material reports maximum and mean absolute differences in head, link flow, and stationary chlorine.

## Software

- MATLAB R2026a with Global Optimization Toolbox and Optimization Toolbox.
- The [STACI repository](https://github.com/hoscsaba/staci) at commit `21816cb`, built with its MATLAB MEX interface as described there. The paper code uses `StaciModel` in memory; it reads each INP once, then updates diameters and solves without candidate-level file operations.
- EPANET 2.2 and the EPANET-MATLAB Toolkit for independent verification and figure geometry. The bundled Apple Silicon library and toolkit loader patch are in `third_party/`.

All scripts accept the location of the STACI checkout and MEX binary directory as arguments. In MATLAB, from this repository root:

```matlab
startup
staci_root = '/path/to/staci';
mex_dir = '/path/to/staci/matlab'; % directory containing staci_mex
addpath(fullfile(staci_root,'matlab'), mex_dir)
validate_environment(staci_root,mex_dir)
```

Check `exist('staci_mex','file') == 3` before long runs. The STACI checkout and this paper repository can be in unrelated directories.

## Reproduction order

The versioned `results_staci/` directories already contain final designs and studies. Replotting does not run a GA.

```matlab
% Five STACI single-objective searches per network, resumable by result MAT:
run_staci_all_optimizations(staci_root,mex_dir)
continue_balerma_hydraulic_entropy(staci_root,mex_dir)
continue_balerma_capped_objective(staci_root,mex_dir,'chlorine_entropy',600)
continue_balerma_capped_objective(staci_root,mex_dir,'todini',840)
finalize_balerma_cross_elites(staci_root,mex_dir)
select_staci_best_feasible_incumbents(staci_root,mex_dir,'balerma')

% STACI reference states and numerical cross-evaluation:
finalize_staci_single_objectives(staci_root,mex_dir)

% Independent EPANET 2.2 check of the 15 saved STACI designs:
addpath('supplementary')
validate_staci_final_designs(staci_root,mex_dir)

% STACI N-1 demand-driven diagnostics and pressure-driven service:
run_staci_outage_studies(staci_root,mex_dir)
verify_balerma_island_handling(staci_root,mex_dir) % addpath('supplementary') above
run_pda_vulnerability_analysis('results_staci')

% STACI pipe rankings and cached nested subset searches:
run_staci_ranking_studies(staci_root,mex_dir,'anytown')
run_staci_ranking_studies(staci_root,mex_dir,'balerma')

% STACI cost–hydraulic-entropy archive and manuscript figures:
run_staci_cost_entropy_front(staci_root,mex_dir)
addpath('manuscript/figures','manuscript/tables')
reproduce_all_figures(staci_root,mex_dir)
```

A ranking search saves each `(objective, criterion, number of free pipes)` result separately in `results_staci/ranking_cache/`. Extending the tested pipe counts reuses completed entries. `run_staci_all_optimizations` likewise skips completed final MAT files unless explicitly asked to rerun. Its 100-member GA has a 150-generation stall limit and a two-hour wall-time safeguard per objective. The high generation ceiling lets MATLAB's convergence rule stop routine cases; the saved MAT and `supplementary/results/staci_single_objective_summary.csv` record actual stop generations, evaluations, wall time, and stop messages. No finite GA run proves global optimality.

The archived Balerma hydraulic-entropy, chlorine-entropy, and Todini runs reached their original 2,000-generation ceilings before the two-hour limit. Their continuation functions resumed from the exact saved incumbents for at most 20, 10, and 14 additional minutes, respectively. The first results remain as `*_stage1.mat`; the stopping audit records combined work. Completed continuation MAT files are reused. The current fresh-run entry point instead starts with a 10,000-generation ceiling and stops at MATLAB convergence or the two-hour wall limit.
For a genuinely fresh search, the three archival continuation calls in the block above can be omitted; they are retained to replay the published staged stopping history from its saved MAT files.

The completed chlorine-entropy run also supplied a slightly better hydraulic-entropy design than the earlier H-only search; the completed chlorine-concentration run supplied a slightly cheaper cost design. `finalize_balerma_cross_elites` uses these cross-objective seeds for short final searches and retains both pre-elite MAT records. This prevents a cross-evaluation diagonal from silently reporting an inferior incumbent.

`select_staci_best_feasible_incumbents` then re-evaluates all five saved vectors in STACI, checks the hydraulic constraints and the 0.2 mg/L consumer constraint for chlorine objectives, and shares a better feasible vector across objective labels when found. It preserves each displaced GA result as `*_ga_raw.mat`. The final design vectors, rather than the displaced GA vectors, are used in all figures, outage replays and EPANET checks.

The Anytown pressure-only basins are zero-demand junctions at nodes 65 and 165, joined by fixed virtual links. They neither inject nor withdraw water. Their **heads** are constrained to `215 ± 0.5 ft`; the physical source is reservoir 10. The true Balerma reservoirs and Tanyimboh–Templeman source remain water-supplying boundaries. For chlorine-directed searches, the 0.2 mg/L constraint applies only to nodes whose requested demand exceeds `π(0.010 m)^2(0.01 m/s)/4 = 7.854×10⁻⁷ m³/s`. Every nominal calculation uses one fixed load and first-order chlorine decay. STACI's direct stationary quality solve is the model used for all reported chlorine objectives and outage outcomes.

In Balerma N-1 replay, failed bridge pipes can isolate junctions from every reservoir. The outage scripts solve only the source-connected network in STACI and assign zero delivery to isolated junctions. They use an outage-only 200-iteration Newton budget and the STACI revision in which a stagnant PDA node is identified from **delivered** demand. `verify_balerma_island_handling` tests the two failure modes. This temporary-INP handling is outside the in-memory optimization loop.

The independent EPANET verification copies each source INP to a case folder, applies the exact saved diameters, and runs extended-period chlorine until the effectively stationary field is reached. EPANET is not called inside any reported STACI optimization fitness or constraint evaluation. The comparison CSV and supplementary PDF state the numerical limits of the agreement.
The generated EPANET case files under `supplementary/results/validation_staci_15/cases/` are ignored by Git; the script recreates them from the source INPs and final MAT files.

## Minimum examples

The Tanyimboh--Templeman reference-flow table is generated by
`wdn.verify_tanyimboh_reference`, which independently maximizes the published
conditional-flow entropy subject to source-flow and nodal-continuity
constraints. It is an analytical check without pipe diameters; the reported
pipe-sizing runs use STACI.

Figure 1 is analytical. The four-pipe, unequal-demand loop used in Figures 2 and 3 is `networks/y_two_consumers/input/network_original.inp`. Its two reproduction scripts use STACI for the inverse hydraulic sizing, seeded chlorine-entropy GA, stationary chlorine, and nodal entropy contributions:

```matlab
make_two_consumer_entropy_example
make_two_consumer_chlorine_entropy_example(true)
```

Pass `false` to the chlorine script to replot its saved pair without rerunning the GA. Both scripts save numerical CSVs in `networks/y_two_consumers/results/` and PNG/SVG in `manuscript/generated/figures/`.

## Repository layout

- `+wdn/`: shared STACI objective, hydraulic, quality, outage, ranking, plotting, and INP utilities.
- `networks/<id>/input/`: EPANET-compatible source INPs; `results_staci/`: the reported STACI calculations and independent cache entries; `figures_staci/`: STACI-based graphics.
- `manuscript/figures/` and `manuscript/tables/`: paper-specific plotting and table procedures; `manuscript/generated/`: graphics and numerical tables supplied to LaTeX.
- `supplementary/`: EPANET verification script and comparison CSVs, plus earlier independent steady-state parity and timing studies.
- `third_party/`: EPANET 2.2 and MATLAB Toolkit for verification.
The earlier EPANET-era optimization outputs and scripts have been removed from this checkout. Git history retains them; `results_staci/` supplies every reported network design. The versioned per-case files under `supplementary/results/<network>/` remain because the stationary-chlorine trajectory figure and CPU benchmark read them.

Each INP and saved result has stable link IDs. The final design MAT files contain full-precision diameters, objective values, constraint violation, GA status, and operating-state arrays. Do not round the diameter vector before cross-engine verification; rounding can matter at active pressure-anchor limits.
