# Entropy and water quality in pipe-diameter design

This repository contains the MATLAB calculations, EPANET-compatible inputs,
saved full-precision designs, failure replays, tables, and editable figure
sources for the accompanying article and Supplementary Material. The
hydraulic and stationary chlorine evaluator is
[STACI](https://github.com/hoscsaba/staci) revision `74d3660`; final nominal designs are also
checked independently with EPANET 2.2. The saved design vectors are the
published numerical record: rerunning a stochastic GA is unnecessary to
redraw the figures.

## Software and quick start

Use MATLAB R2026a with Optimization Toolbox and Global Optimization Toolbox.
Build `staci_mex` as described in the
[STACI MATLAB README](https://github.com/hoscsaba/staci/blob/master/matlab/README.md).
The EPANET MATLAB Toolkit in `third_party/` is used for network geometry and
independent verification. From this repository's root:

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

The ranked-subset and Pareto studies are separate searches on the saved
nominal feasible set. Balerma's ranked subsets use up to 90 of 454 pipes;
its Pareto search also varies a fixed top-90 subset. Search checkpoints are
indexed by objective, ranking, and subset size, so larger subsets can be
added without recomputing smaller ones. The reported GA endpoints are finite
best-found results, not global-optimality certificates.

## Recompute and verify

Read [the calculation sequence](docs/REPRODUCIBILITY.md) for TT and Anytown
and [the R38-anchor run guide](networks/balerma/R38_ANCHOR_RUN.md) for Balerma.
The latter documents the six full-network searches, feasible-seed
refinements, ranked subsets, Pareto search, 448-case PDA replays, and
independent EPANET checks. Each fitness call updates an in-memory STACI
model; temporary INP files appear only in the independent EPANET validation
and some failed-state replays. Exact saved diameters should be used: rounding
can change feasibility near an active pressure or chlorine bound.

The final STACI–EPANET comparison files are in `supplementary/results/` for
TT and Anytown and in the Balerma final result directory's
`epanet_validation/`. The stationary-quality comparison advances EPANET
quality until a fixed-load near-steady field is reached. Neither solver
represents diurnal tank-level evolution in the nominal optimization.
Supplementary Section 2 also reports an earlier four-source, 10–500 mm
Balerma solver-validation set; its exact archived vectors are retained in
`networks/balerma/results_staci/` solely to reproduce that historical
numerical cross-check. They do not supply the current Balerma design figures
or service tables.

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
