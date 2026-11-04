# Reproducing the article calculations

## Configuration authority

Each network's `network_config.m` is the sole authority for diameter bounds,
pressure constraints, water-quality duration and step, cost coefficients, GA
settings, ranking range, source concentrations, and entropy exclusions. Do not
duplicate these constants in a driver script. The article settings are:

| Network | Variables | Population | Generations | Stall | RNG seed | Quality step |
|---|---:|---:|---:|---:|---:|---:|
| Tanyimboh–Templeman | 8 | 100 | 500 | 100 | 1993 | 48 h |
| Anytown | 38 | 100 | 100 | 30 | 1993 | 3 h |
| Balerma | 454 | 100 | 100 | 30 | 1993 | 1 h |

All calculations are sequential (`UseParallel=false`). The shared mutable
EPANET object must not be used concurrently by MATLAB workers.

## Recommended workflow

1. Run `validate_environment`, `run_smoke_test`, and
   `validate_saved_results`.
2. Run the network-specific optimization entry point.
3. Inspect each result's `exitflag`, `output.generations`,
   `max_constraint_violation`, `incumbent_guard_applied`, and timings.
4. Synchronize the shared feasible archive, then regenerate the
   cross-evaluation. If one search found a design that dominates another
   objective's incumbent, the selected record changes but the raw GA return is
   retained in `optimizer_returned_*` fields. It remains an error if another
   topology beats the synchronized incumbent in its own column.
5. Only then regenerate stress tests, relationship summaries, and figures.

The GA is stochastic even with a fixed random seed across MATLAB versions and
platforms. Reproducibility therefore means identical model definition and
solver settings plus validated, auditable convergence—not a promise of
bit-for-bit identical diameter vectors on every system.

## Result provenance

Production MAT files contain the design-link order and diameters, all five
physical metrics, raw pressure-constraint violation, optimizer/exit metadata,
random seed, MATLAB timings, and a creation timestamp. CSV files are derived
views for the article; MAT files are the authoritative machine-readable record.

Balerma's `seeds/initial_designs.csv` contains historical warm starts in INP
pipe order. Warm starts are never reported directly as new optimization
results. The incumbent guard can select one only when it is feasible and better
under the objective being run; this event is recorded in the result structure.

`validate_saved_results` accepts a maximum relative metric difference of
`1e-6` when replaying saved designs. This accommodates native EPANET floating-
point variation while remaining far below the precision reported in the paper.
