# Entropy and water quality in pipe-diameter design

This repository contains the MATLAB calculations, EPANET-compatible inputs,
saved full-precision designs, failure replays, tables, and editable figure
sources for the accompanying article and Supplementary Material. The
hydraulic and stationary chlorine evaluator is
[STACI](https://github.com/hoscsaba/staci) revision `74d3660`. Every
optimized nominal diameter vector displayed in the current paper and Supplementary
Material has a post-search EPANET 2.2 comparison; flagged differences are
recorded rather than treated as exact agreement. The saved design vectors are
the published numerical record: rerunning a stochastic GA is unnecessary to
redraw the figures.

The submitted [main article PDF](docuemnts/main.pdf) and
[Supplementary Material PDF](docuemnts/supplementary_staci.pdf) are included
in this repository. The `docuemnts/` spelling is retained because the
submitted article links to that path. Publication PNGs in the manuscript
package are compressed; this repository keeps their full-resolution renders
and editable SVGs.

## Citation and manuscript sources

The [citation metadata](CITATION.cff) identify this software and data release. When citing a calculation, give the repository URL and the exact Git commit; no archival DOI has yet been assigned. The article and Supplementary Material have two LaTeX source files, `main.tex` and `supplementary_staci.tex`, in the accompanying manuscript directory. This repository contains their calculation and figure sources. The GPL-2.0 license applies to article-specific code; bundled third-party components retain their own licenses.

## Software and quick start

Use MATLAB R2026a with Optimization Toolbox and Global Optimization Toolbox.
Build `staci_mex` as described in the
[STACI MATLAB README](https://github.com/hoscsaba/staci/blob/master/matlab/README.md).
The EPANET MATLAB Toolkit in `third_party/` is used for network geometry and
independent verification. For exact reproduction of the published numerical
record, check out STACI commit `74d3660` before building its MATLAB MEX
interface. Later STACI revisions may contain changes, so the pinned commit
identifies the tested solver. From this repository's root:

```matlab
startup
paper_root = pwd;
staci_root = '/absolute/path/to/staci';
mex_dir = '/absolute/path/to/staci/build-matlab/Matlab';
validate_environment(staci_root,mex_dir)
addpath('manuscript/figures','manuscript/tables','supplementary')
reproduce_all_figures(staci_root,mex_dir)
export_manuscript_tables
```

`validate_environment` checks the two toolboxes, MEX module, three final
inputs, and all 18 nominal design checkpoints. `reproduce_all_figures`
replots the **current** article and Supplementary figures from released data;
it runs neither a network GA nor new pipe-failure cases. The four-pipe
illustrations do solve their small nominal hydraulic model. MATLAB-generated
PNG/PDF figures and editable SVGs are in `manuscript/generated/figures/`.
The exact figure and table sources are listed in
[the publication manifest](manuscript/MANIFEST.md).

## Final network models

| Network | Nominal optimization | Failure replay | Final result directory |
|---|---|---|---|
| Tanyimboh–Templeman | Node 1 is a 50 m fixed-head source; node 2 is a prescribed inflow | Eight physical pipe closures per design, with PDA | `networks/tanyimboh_templeman/results_staci_10_120_clsplit_v2/` |
| Anytown | Pump supplies demand; R65 and R165 are zero-flow pressure anchors at 215 ± 0.5 ft | Both auxiliary reservoirs restored; 38 pipe closures under three reservoir-availability states, 114 cases | `networks/anytown/results_staci_anchor_replay/` |
| Balerma | R38 is a zero-flow 117 m pressure anchor; R43, R44, R88 remain physical reservoirs | All four reservoirs restored, then R38 unavailable; six direct reservoir connectors protected, 448 pipe closures per state | `networks/balerma/results_staci_r38_anchor_r44_physical_0p1_64in_v1/` |

All six objectives (cost, hydraulic entropy, branch-hop-weighted hydraulic
entropy, squared chlorine concentration, chlorine-mass-splitting entropy,
and Todini index) use the same nominal 0.1–64 in continuous diameter range,
10–120 m assessment-junction pressure limits, and at least 0.2 mg/L chlorine
at material-demand consumers. The latter threshold is a demand greater than
the flow in a 10 mm pipe at 1 cm/s, or `7.854e-7 m^3/s`. Anytown and Balerma
have the additional anchor-head constraints above. Branch-hop weights use
undirected topology and all *potential* supply entries; flow direction does
not enter the weights. See [objective definitions](docs/OBJECTIVES.md) and
[methods](docs/METHODS.md).

The released Anytown nominal input derives from `network_initial_feasible.inp`.
Compared with the preserved benchmark, only P6 (20–110) changes, from 12 to
14.88 in. This makes the initial K=0 candidate feasible; it does
not change the 0.1–64 in optimization bounds or any other initial pipe.

The ranked-subset and Pareto studies are separate searches on the saved
nominal feasible set. Balerma's ranked subsets use up to 90 of 454 pipes;
its Pareto search also varies a fixed top-90 subset. Search checkpoints are
indexed by objective, ranking, and subset size, so larger subsets can be
added without recomputing smaller ones. The reported GA endpoints are finite
best-found results, not global-optimality certificates.

Regenerate the ranked-pipe progress tables from the saved CSVs with
`addpath('manuscript/tables'); export_ranked_progress(pwd)` in MATLAB.
The exported all-K and representative-K CSVs in `manuscript/generated/tables/`
show the percentage of each objective's feasible K=0-to-full improvement
reached by a restricted search. The full-network reference is a finite-search
best-found design, not a certified global optimum.

## Recompute and verify

Read [the calculation sequence](docs/REPRODUCIBILITY.md) for TT and Anytown
and [the R38-anchor run guide](networks/balerma/R38_ANCHOR_RUN.md) for Balerma.
The latter documents the six full-network searches, feasible-seed
refinements, ranked subsets, Pareto search, 448-case PDA replays, and
independent EPANET checks. Anytown’s released Todini endpoint includes a
post-GA, full-network SQP refinement seeded by a 35-pipe ranked result. Its
GA and SQP evaluations and times are reported separately in
`networks/anytown/results_staci_anchor_replay/ga_stop_six.csv`. Each
fitness call updates an in-memory STACI model; temporary INP files appear only in the independent EPANET validation
and some failed-state replays. Exact saved diameters should be used: rounding
can change feasibility near an active pressure or chlorine bound.

Before releasing new figures or tables, run the mandatory post-search
audit on every displayed nominal diameter vector:

```matlab
addpath('supplementary')
validate_reported_nominal_designs(staci_root,mex_dir)
```

The script reconstructs fresh EPANET 2.2 and STACI models from each matched
fixed-load INP, checks heads, signed flows, consumer chlorine and design
constraints by node/link ID, and writes a resumable checkpoint and CSV to
`supplementary/results/nominal_design_validation/`. The released
[1,369-row audit and interpretation guide](supplementary/results/nominal_design_validation/README.md)
cover the 18 final single-objective designs, plotted ranked subsets, the TT
and Anytown Pareto archives, and 20 selected Balerma Pareto points. Numerical
flags remain visible in the CSV. The older six-design comparison CSVs remain
the detailed source for the Supplementary solver-comparison tables. This
nominal audit does not replay PDA pipe-failure states; neither solver
represents diurnal tank-level evolution in the nominal calculation.

## Repository map

- `+wdn/`: shared STACI evaluators, constraints, objective functions, ranking,
  PDA replay, and plot helpers.
- `networks/<name>/input/`: model INPs. Each network's final result directory
  contains exact MAT vectors and auditable numerical CSVs.
- `manuscript/figures/`: publication-specific plotting scripts;
  `manuscript/generated/figures/`: rendered assets and editable SVGs.
- `manuscript/tables/`: saved-data table exports.
- `supplementary/`: solver comparison, timing, and EPANET validation scripts;
  `supplementary/results/`: released verification records.
- `third_party/`: the EPANET MATLAB Toolkit and EPANET 2.2 components.

The Balerma benchmark originates from
[Reca and Martínez (2006)](https://doi.org/10.1029/2005WR004383). The
repository's saved initial diameter vector differs from the published
assignment, although its network topology, demands and pipe identifiers
are retained. “Original” in our figures means this released starting
vector. The finite outage frequencies are conditional on the enumerated
cases, not annual failure probabilities.
