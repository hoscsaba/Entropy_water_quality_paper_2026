# Reproducing the STACI calculations

## Required software

Use MATLAB R2026a with Optimization Toolbox and Global Optimization Toolbox, the MATLAB MEX interface from the [STACI repository](https://github.com/hoscsaba/staci) at revision `21816cb`, and EPANET 2.2 with the EPANET-MATLAB Toolkit for independent verification. The optimizer keeps one `StaciModel` in memory, updates pipe diameters there, and calls the hydraulic and direct stationary-quality solvers. It writes no per-candidate INP or quality history.

## Current Anytown sequence

The [README](../README.md#recalculate-designs) gives the executable MATLAB call order. The current nominal input is `networks/anytown/input/network_anchor_replay.inp`; R65/R165 are zero-flow pressure anchors with terminal heads constrained to 215 ± 0.5 ft. R10/pump supplies all fixed demand. `network_config_anchor_replay.m` sets these boundaries, the EPANET-consistent pressure conversion, and small internal feasibility margins. The six final MAT designs are in `results_staci_anchor_replay/`.

The failure runner transfers each exact saved diameter vector to `network_physical_reservoirs.inp`. R65/R165 then have physical 215-ft head and may inject or absorb water. It closes each of 38 physical pipes with both, only R65, or only R165 connected, while R10/pump stays open. The availability input is checked for open connectors and 215-ft heads before replay. This produces 114 equally weighted cases per design, with demand-driven diagnostics and pressure-driven service. The pooled CSVs are in `results_staci_anchor_replay/`.

`run_anytown_anchor_replay_rankings.m` caches every `(objective, ranking, K)` result separately. An interrupted or extended run reuses completed points. For four of the five rankings, no feasible incumbent was found at K=1 under the nominal design constraints; those CSV metrics are `NaN`. The entropy-sensitivity ranking has a feasible K=1 design. The initial GA also missed K=2 for those four rankings, but `find_anytown_anchor_replay_k2_seed.m` found a feasible two-pipe diameter vector by minimizing constraint violation with bounded pattern search. The subsequent objective GAs use that seed, so all K=2 points are now present. Once a feasible design is found, its complete diameter vector and all cross-evaluated metrics are carried forward whenever a later independently stopped GA returns a worse objective. The original diameter vector at K=0 is an evaluated plotting reference; it violates at least one nominal design constraint and is outside this monotonicity guarantee. `run_anytown_anchor_replay_pareto.m` saves a finite cost–branch-hop archive. Both use the same nominal model as the six full-network searches.

`verify_anytown_anchor_replay_rankings.m` independently re-solves the 304 feasible saved Figure 9–10 vectors. It checks released-pipe membership, diameter bounds, nominal constraints, all archived metrics, monotonicity of the optimized objective after the first feasible subset, and equality of the K=38 endpoint with the final full-network design. Its machine-readable output is `ranking_figures_9_10_audit.csv`. The largest relative archived-versus-recomputed metric difference in the current archive is 0.0322%, within the stated 0.05% audit tolerance; the maximum recomputed constraint violation is 0.000040 psi, below the 0.000050 psi optimizer tolerance. The plotters show infeasible K=0 as a disconnected black square.

`reproduce_all_figures(staci_root,mex_dir)` reads the saved Anytown, Balerma and Tanyimboh–Templeman data; it does not launch a network GA. `export_manuscript_tables` collects the numerical CSVs behind the manuscript. The released Anytown inputs are only `results_staci_anchor_replay/`; obsolete nominal design variants were removed from this reproduction repository.

## Independent check and interpretation

`supplementary/validate_staci_final_designs.m` applies each final full-precision diameter vector to the matched nominal INP in EPANET 2.2. The current six-design Anytown CSV is `supplementary/results/validation_anytown_anchor_replay/staci_epanet_anytown_anchor_replay_six.csv`; it gives maximum and mean absolute differences in total head, signed link flow and chlorine. EPANET quality is advanced for 14 days with five-minute steps to approximate the stationary field. The saved vectors satisfy the EPANET pressure and anchor-head limits. The supplementary PDF reports the comparison alongside the STACI equations and numerical tolerances.

The Tanyimboh–Templeman and Balerma calculations use their own `results_staci/` directories. Balerma keeps all four physical reservoirs connected in nominal optimization and failure replay; its restricted branch-hop design has 45 of 454 pipes free. The complete rerun procedure is [BALERMA_CONNECTED_RUN.md](BALERMA_CONNECTED_RUN.md). Its bridge-pipe failures use a temporary source-connected outage INP and assign zero delivery to disconnected nodes. That file handling occurs only in failure replay, not in the optimizer.

The reported GA vectors are finite, best-found designs, not mathematical proofs of global optimality. Stress-test service values are conditional on the enumerated failures and one fixed demand state, not annual probabilities. Consult [the methods](METHODS.md) for exact boundaries, source handling, and service definitions.

## Released-data audit and full regeneration

The quick path in the root README re-renders figures and exports tables from saved full-precision vectors. It does not claim to repeat a stochastic GA. For a new GA, save the released MAT files elsewhere first, then remove only the endpoint(s) you want to recompute. Anytown's `run_anytown_anchor_replay_optimizations` uses released endpoints and `cost_local_seed.mat` as feasible warm starts; all candidates are re-evaluated under the nominal anchor constraints. Its two endpoint-refinement scripts reproduce the documented continuation after the first ranking pass. Balerma's `run_balerma_connected_full` writes a separate staging folder; only reviewed, independently verified vectors belong in canonical `results_staci/`.

For the published independent checks, run `validate_staci_final_designs` with the exact nominal INP and full-precision saved vectors, for example:

```matlab
addpath('supplementary')
validate_staci_final_designs(staci_root,mex_dir, ...
    fullfile(paper_root,'supplementary','results','validation_staci_tanyimboh'), ...
    'tanyimboh_templeman')
validate_staci_final_designs(staci_root,mex_dir, ...
    fullfile(paper_root,'supplementary','results','validation_anytown_anchor_replay'), ...
    'anytown',{},'anchor_replay')
validate_staci_final_designs(staci_root,mex_dir, ...
    fullfile(paper_root,'supplementary','results','validation_staci_balerma_connected'), ...
    'balerma')
```

The Anytown check expects pump-only nominal supply and zero flow through links 78/80. During outage replay, R65/R165 are restored at 215 ft; an unavailable reservoir is isolated by closing only its connector. Balerma is different: all four reservoirs remain physical sources in both phases. EPANET quality is advanced for 14 days with five-minute steps to approximate the stationary STACI field. The released CSVs report maximum and mean absolute head, signed-flow, and chlorine differences.
