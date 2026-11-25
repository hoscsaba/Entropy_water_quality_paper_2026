# Tanyimboh–Templeman calculation

The [fixed-load EPANET input](input/network_staci_fixed_load.inp) has eight variable pipes. Node 1 is a 50 m fixed-head source; node 2 has prescribed inflow. No storage pressure anchor or reservoir-outage scenario is used for this network. The common nominal constraints and objective definitions are in [the repository README](../../README.md) and [OBJECTIVES.md](../../docs/OBJECTIVES.md).

The exact six submitted single-objective diameter vectors, ranked-subset searches, Pareto archive, and failure-service records are in [`results_staci_10_120_clsplit_v2/`](results_staci_10_120_clsplit_v2/). Use the saved full-precision MAT vectors to reproduce the article; a new genetic search may finish at a different feasible point. Each of the eight physical pipes is closed once for the pressure-driven failure assessment.

[The step-by-step calculation sequence](../../docs/REPRODUCIBILITY.md#tanyimbohtempleman-full-calculation-sequence) identifies the search, cross-evaluation, EPANET verification, outage replay, and plotting commands. The [publication asset manifest](../../manuscript/MANIFEST.md) maps each displayed figure to its script and saved numerical input. Start with `startup` and `validate_environment` as shown in the root README.
