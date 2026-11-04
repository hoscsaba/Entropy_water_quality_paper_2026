# Entropy water-quality paper 2026

This directory contains the MATLAB code, EPANET inputs, validated result files,
and plotting routines used by the accompanying article. It is structured as a
standalone GitHub repository: no function depends on an absolute path or on a
file elsewhere on the original author's computer.


## Article methods and pressure-driven service replay

Detailed software settings, validation checks, boundary handling, and the new deterministic N−1 service indicators are documented in [`docs/METHODS.md`](docs/METHODS.md). To reproduce the saved-design replay without any new optimization, run `startup; run_pda_service_study`. For the conditional vulnerability summaries and pipe-ranking validation, run `run_pda_vulnerability_analysis` after the replay; this post-processing does not call EPANET. The network-specific result files are `networks/<id>/results/pda_service_summary.csv` and `pda_service_scenarios.csv`.

## Requirements and first run

- MATLAB R2026a (26.1) was used for the reported results.
- Global Optimization Toolbox supplies `ga` and `gamultiobj`.
- Optimization Toolbox supplies solver infrastructure and `patternsearch`.
- EPANET 2.2 and EPANET-MATLAB Toolkit 2.2.6.5 are included under
  `third_party/`; their own licences apply.

In MATLAB, change to this directory and run:

```matlab
startup
validate_environment
run_smoke_test
validate_saved_results
```

`validate_environment` checks versions, toolboxes, inputs, portable paths, and
the stored cross-evaluation diagonals without running an optimization. The
smoke test opens the smallest network and evaluates all five metrics.
`validate_saved_results` independently re-evaluates every stored production
design through EPANET and checks metric regression and raw pressure feasibility.

## Layout

- `+wdn/`: reusable EPANET, objective, optimisation and plotting functions.
- `networks/<network_id>/`: one self-contained directory per network, including
  immutable `input` and generated `runtime`, `results` and `figures` material.
- `manuscript/figures/`: figure-specific post-processing functions.
- `manuscript/tables/`: numerical table exporters and relationship summaries.
- `manuscript/generated/`: versioned figures and table data used by the paper.
- `third_party/`: the upstream EPANET-MATLAB Toolkit, the official EPANET 2.2
  Apple-Silicon library, third-party licences, and the documented loader patch.
- `docs/`: objective definitions, reproduction workflow, and extension notes.
- `run_smoke_test.m`: opens each registered INP file through EPANET and evaluates
  the unmodified design.

The `+wdn` MATLAB package is the shared utility layer. Network-specific data
and configuration are confined to `networks`, while paper-only presentation
logic is confined to `manuscript`. See `manuscript/MANIFEST.md` for the exact
figure/table-to-script mapping.

## Reproducing paper figures and tables

The following commands use the saved validated results and do not launch a
genetic algorithm:

```matlab
startup
reproduce_all_figures
export_manuscript_tables
```

Outputs remain inside `manuscript/generated`. The repository therefore does
not depend on a neighboring LaTeX checkout or on the original author's paths.

## Reproducing the two-consumer minimum examples

From the repository root, run:

```matlab
startup
make_pressure_anchor_mwe_figure
make_two_consumer_entropy_example
make_two_consumer_chlorine_entropy_example
```

Figure 1 is an analytical pressure-anchor example. Figure 2 and the next
chlorine-entropy figure use the same EPANET 2.2 four-pipe loop in
`networks/y_two_consumers/input/network_original.inp`: D1 requests 0.8 L/s,
D2 requests 1.3 L/s, and every pipe is 3 km long. The Figure 2 script first
maximizes hydraulic flow entropy analytically, solves one pipe diameter for
the maximizing flow split, and doubles all diameters to construct another
design with identical flows and entropy. Both consumer pressures remain above
20 m.

The chlorine script runs a seeded GA with EPANET chlorine transport
(1 mg/L at the source, -1/day bulk decay, 48 h terminal time) and requires
at least 0.2 mg/L at both consumers. It then changes the D1--D2 pipe
and solves the J--D2 diameter to preserve the GA design's complete flow
vector. Two resulting feasible designs have the same chlorine entropy but
D2 residuals around 0.751 and 0.491 mg/L. The chlorine-entropy
contributions at S, J, D1, and D2 are respectively 0, 0.59159255,
0.38600168, and 0 nat in *both* designs. The result CSVs report these
contributions separately, and the figures place each value next to its
corresponding node, together with head, chlorine residual, and consumer
withdrawal where applicable. This is an objective-level
non-uniqueness construction near the best-known GA result; the GA does not
certify a global optimum. The scripts save CSV/MAT results under
`networks/y_two_consumers/results` and PNG/SVG assets under
`manuscript/generated/figures`. The script
`manuscript/figures/reproduce_all_figures.m` replots the saved chlorine pair
without rerunning GA. See [`docs/METHODS.md`](docs/METHODS.md) for equations
and exact values.

The three optimization networks are `tanyimboh_templeman`, `anytown`, and
`balerma`. The Tanyimboh--Templeman `network_config.m` explicitly
distinguishes the eight physical benchmark pipes from the artificial EPANET
supply connector `P_input_2`.  The connector remains fixed and is excluded from
the construction cost and design vector.

## Running the Tanyimboh–Templeman case

From MATLAB, change to this directory and run:

```matlab
run_smoke_test
run_optimizations
make_figure3
```

`run_optimizations` runs five single-objective genetic algorithms: cost,
hydraulic entropy, chlorine concentration, chlorine entropy and the Todini
index.  MATLAB's `ga` always minimises, so maximised physical metrics are
negated only in `wdn.objective_value`; saved reports retain their positive,
physical values.

The validated MATLAB R2026a setup uses Global Optimization Toolbox `ga` with
its nonlinear-constraint penalty algorithm and a constrained `patternsearch`
hybrid refinement. Otherwise the code automatically
uses the included sequential `wdn.simple_ga` fallback with feasible-first
constraint handling. Saved production results are rejected if the configured
pressure tolerance is violated. A final raw-EPANET feasibility check can move a
solution minimally toward the upper-bound design when the solver's internally
scaled constraint tolerance would otherwise leave a small pressure shortfall.

`make_figure3` writes `networks/tanyimboh_templeman/figures/figure3.png` as a
2-by-3 matrix in this fixed order:

1. original layout, 2. cost, 3. hydraulic entropy,
4. chlorine concentration, 5. chlorine entropy, 6. Todini index.

Nodes use one shared pressure colour scale.  Pipe width is scaled from the
physical diameter using one scale across all six panels.  Pipes at the lower
diameter bound are dashed to indicate links that the continuous optimiser has
effectively removed.

## Running the Anytown case

From the same MATLAB directory, run:

```matlab
run_anytown_optimizations
make_anytown_figures
run_anytown_cost_entropy
benchmark_anytown_optimization_times
run_anytown_stress_test
run_anytown_ranking_study
```

To regenerate only Figure 9 from the saved ranking results, without launching
any optimization, run:

```matlab
regenerate_anytown_ranking_figure
```

The first command evaluates the original network, runs the five 38-variable
single-objective GAs, validates every saved design against the 33--165 psi
pressure interval, and writes both raw and normalized cross-evaluation CSV
files. The second command uses only the saved results to create Figure 4 with
pressure coloring and Figure 5 with chlorine coloring. Both figures contain the
original layout plus cost, hydraulic entropy, chlorine concentration, chlorine
entropy, and Todini optima in a 2-by-3 matrix.

`run_anytown_cost_entropy` performs the cost--hydraulic-entropy Pareto search
used for Figure 7. Marker color gives the independently evaluated chlorine
objective `sum(C.^2)`, while a mildly nonlinear marker-area scale emphasizes
differences in chlorine entropy without hiding low-entropy points. Water
quality is evaluated only for the final Pareto set,
because neither chlorine metric participates in this optimizer.

`benchmark_anytown_optimization_times` repeats the five sequential Anytown GA
searches without overwriting their validated production results. It writes
process CPU time, elapsed wall-clock time, function evaluations, generations,
and CPU time normalized to the shortest run to `optimization_timing.csv`.

Anytown uses a population of 100, at most 100 generations, and 30 stall
generations. A feasible 215-ft pressure-anchor design and all compatible saved
single-objective optima warm-start the population. The hybrid pattern search is
intentionally disabled for this 38-variable case
because every chlorine-objective mesh evaluation entails another complete 48 h
EPANET quality simulation.

`run_anytown_stress_test` closes each of the 38 physical design pipes in turn
for every saved optimum. It evaluates pressure and final 48 h chlorine at the
19 configured consumer junctions; the true source and the two zero-flow
pressure-anchor nodes are excluded. The command
writes `stress_test.csv` with topology-level results and
`stress_test_scenarios.csv` with one auditable row per failed pipe.

`run_anytown_ranking_study` reproduces the five physical-pipe rankings and the
pressure-anchor version of Figure 9. It excludes pump 82 and virtual anchor
adapters 78 and 80, ranks the remaining 38 pipes about the documented feasible
reference design. It performs separate nested cost and hydraulic-entropy
optimizations for `K = [0:10 15 20 25 30 35 38]` pipes in each ranking and
cross-evaluates all five physical objectives on every resulting network. The
`K=0` point is the original unoptimized INP state and is flagged infeasible
with respect to the pressure anchors. All reduced searches use the same
population 100, generation 100, stall 30, and seed 1993 settings as the full
production GA. Missing metric rows identify subsets for which the two anchor
bands cannot be satisfied. The best `K=35` designs warm-start additional full
38-variable endpoint refinements. The command writes the
top-20 ranking CSV, two complete cross-evaluation CSV/MAT series, and both PNG
and vector SVG versions of the ten-panel objective matrix. The refined endpoint
files are stored separately from the earlier single-objective production MAT
files so that the convergence audit remains traceable.

## Reproducibility notes

- The archived optimization invokes EPANET on an `.inp` through the bundled
  EPANET-MATLAB Toolkit. A separate Python verifier uses the official EPANET
  2.2 shared library to record long fixed-load chlorine histories.
- `third_party/epanet22_arm64` contains a native Apple-Silicon build of the
  official EPANET 2.2 (`v2.2`) library.  It is selected explicitly because the
  older toolkit bundle contains only an Intel macOS binary.
- `third_party/epanet_matlab_toolkit_patch` is an otherwise unchanged copy of
  the toolkit class with two macOS loading fixes: platform-neutral path
  separators and loading the dynamic library by its explicit full path.
- The toolkit is found under this repository's `third_party` directory. A
  system installation can override it with the `WDS_EPANET_TOOLKIT`
  environment variable.
- Parallel fitness evaluation is disabled by default.  The toolkit object is
  mutable, so sharing one instance among MATLAB workers can mix candidate
  states.  Parallel execution should only be re-enabled after introducing one
  independent EPANET instance per worker.
- The original code returned negative values for metrics that were maximised.
  The new code separates physical metrics from optimiser sign conventions.
- The older `network_originalB.inp` is not used: it changes source forcing,
  reservoir head and initial diameters and therefore represents a different
  hydraulic problem.
- Hydraulic entropy uses the natural-log definition in the reference paper and
  excludes the artificial supply connector. The implementation reproduces the
  paper's 2.41098 entropy value from its published Table 1 flow distribution.
- Both external inflows (the reservoir connector and negative-demand node 2)
  are explicitly assigned the configured 1 mg/L chlorine concentration.

## Running the Balerma case

```matlab
run_balerma_optimizations
make_balerma_figures
run_balerma_stress_test
run_balerma_ranking_study
run_chlorine_ranking_study("balerma")
make_objective_relationship_summary
```

The first command runs all five 454-variable optimizations. A single affected
objective can be resumed without overwriting the other four, for example:

```matlab
run_balerma_optimizations("hydraulic_entropy")
```

Every compatible saved optimum is admitted as a feasible cross-objective elite.
After each GA, an incumbent guard retains the best feasible elite if the search
returns a worse design. At the end of a run, the shared objective archive also
checks whether a design discovered under one objective improves another saved
incumbent. If so, the better feasible design is selected for that objective and
the raw GA return is retained in `optimizer_returned_*` audit fields.
`wdn.write_cross_evaluation` then refuses to publish a normalized table when
any objective's diagonal differs materially from 1. This prevents objective
execution order or premature convergence from silently producing the Table 8
inconsistency discussed during the article audit.

Generated EPANET scratch files live in `networks/*/runtime` and are ignored by
Git. Curated MAT/CSV results and article figures are versioned because they are
the audit trail for the reported tables and plots. Delete or move a result MAT
file only when a deliberately clean rerun is intended.

## Supplementary steady-chlorine check and new STACI searches

The new manuscript version distinguishes the archived 48-hour EPANET results
from a **separate fixed-load experiment**. The three
`networks/*/input/network_staci_fixed_load.inp` files are the common inputs for
STACI and EPANET 2.2. Anytown's original demand pattern is frozen at its
initial multiplier (0.7); its two pressure-only anchors remain zero-demand
junctions. The steady experiment cannot reproduce the archived Anytown
time-varying 48-hour field.

Build STACI with MATLAB MEX support (see the STACI repository), then run in
MATLAB R2026a with the Global Optimization Toolbox:

```matlab
startup
run_staci_chlorine_optimizations('/path/to/staci', ...
    '/path/to/staci/build/matlab', ...
    {'tanyimboh_templeman','anytown','balerma'})
```

The saved results are in `networks/*/results_staci_constrained`. The two
objectives are terminal `sum(c.^2)` and chlorine-weighted flow entropy. Both
impose at least 0.2 mg/L only at junctions with demand greater than
`pi/4*(0.010 m)^2*(0.010 m/s) = 7.854e-7 m3/s`. Pressure and the two Anytown
target-head bands remain nonlinear constraints. Feasible archived designs are
warm starts; the Balerma concentration result is the retained saved cost
incumbent after a fresh GA did not improve it.

The independent comparison script requires Python 3, NumPy, the STACI CLI,
and an EPANET 2.2 shared library. For example:

```sh
python3 supplementary/compare_steady_chlorine.py \
  --staci /path/to/staci/build/staci \
  --output supplementary/results \
  --max-days 14
```

Use `--design-source results_staci_constrained --designs chlorine_concentration,chlorine_entropy`
and a separate output directory for the new GA designs. The script compares
every node after a 14-day EPANET EPS, identifies a stable tail within
`1e-4 mg/L`, and writes both the time histories and the all-node differences.
The committed `supplementary/results` tree contains the curated CSV, common
INP, and representative trajectory data for the 18 archived and six new
designs; temporary EPANET reports and process logs are omitted. In MATLAB:

```matlab
plot_steady_chlorine_trajectories('supplementary/results')
plot_new_chlorine_designs('supplementary/results')
benchmark_staci_epanet_matlab('supplementary/results', ...
    '/path/to/staci', '/path/to/staci/build/matlab')
```

The CPU benchmark times in-memory hydraulic-plus-quality evaluations, after
one input load per design. It excludes startup and parsing and uses each
design's measured EPANET convergence hour. It is not an EPS validation for
changing demand, tank levels, controls, or non-first-order reactions.
