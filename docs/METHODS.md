# Computational methods and reproducibility

The manuscript uses STACI for every reported fixed-load hydraulic and chlorine calculation. The [repository README](../README.md) gives the execution order and software requirements. The accompanying supplementary material gives the stationary solver equations, cross-engine verification and CPU timing. This document records implementation choices useful when adapting the code to another network.

## Inputs and units

Each `networks/<id>/input/network_staci_fixed_load.inp` is an EPANET-compatible INP and is the shared model input for STACI and the independent EPANET check. Network configuration is in `network_config.m`. Anytown physical diameters are expressed in inches, lengths in feet, pressure limits in psi and flow in GPM; its STACI MEX interface converts the physical state to SI. Tanyimboh–Templeman and Balerma designs use millimetre diameters. Metric and constraint conversions are explicit in `+wdn/`.
The source INPs prescribe Hazen–Williams head loss for Tanyimboh–Templeman and Anytown, and Darcy–Weisbach for Balerma. The STACI hydraulic solve respects those imported options; quality uses the same fixed-load hydraulics and first-order reaction settings.

The reported optimization state is one fixed demand snapshot per network. Anytown's demand pattern is held at its initial 0.7 multiplier. There is no tank time evolution, valve schedule, or diurnal loading in the nominal search. Chlorine at a fixed hydraulic state is STACI's direct stationary first-order solution, with 1 mg/L source concentration, bulk coefficient −1 day⁻¹ and zero wall decay. The source and reaction settings are in the INP, rather than being imposed separately by a plotting script.

## Boundary conditions

A true reservoir may exchange water with the service network. The two Anytown legacy basin locations are instead modelled as zero-demand junctions 65 and 165 connected by fixed virtual links. A junction cannot withdraw or inject water through a zero-demand terminal connection except for numerical continuity residual. The GA separately constrains the total hydraulic head at each to 215 ± 0.5 ft. These virtual links, pump 82 and reservoir boundary adapters are excluded from pipe-size variables, flow-entropy service branching and physical-pipe outage selection. The original unoptimized Anytown network violates the two anchor-head bands; it is shown only as a reference state.

Pressure constraints and the Anytown anchors are checked on every GA candidate. The final Anytown search uses an internal 0.00025-ft margin at the 0.5-ft anchor limit to absorb cross-engine roundoff when EPANET independently verifies the saved result. The published physical band remains 0.5 ft. Chlorine-directed GAs also require `c_i ≥ 0.2 mg/L` at material-demand consumers, defined by requested demand exceeding `π(0.010 m)^2(0.01 m/s)/4`. The constraint is not applied to zero-demand anchor or stagnant nodes.

## Genetic searches

`run_staci_all_optimizations.m` launches cost, hydraulic entropy, squared chlorine concentration, chlorine entropy and Todini searches. All have a population of 100 and a stall allowance of 150 generations. The current generation ceiling is 10,000 for all three networks; the archived Balerma searches began with a 2,000-generation ceiling and were continued where needed. A two-hour wall safeguard prevents an unexpectedly slow objective from running without bound. Actual generation, function evaluations, MATLAB stop message, elapsed wall time, seed source and constraint violation are stored in each result MAT and summarized under `supplementary/results/`. A function-tolerance stop is evidence of MATLAB's stopping rule, not a proof of global optimality. The finite best-known feasible incumbent is retained even when a penalty result is marginally infeasible.

The Balerma hydraulic-entropy, chlorine-entropy, and Todini runs reached
their 2,000-generation ceilings in approximately 97, 110, and 105 minutes.
`continue_balerma_hydraulic_entropy.m` and
`continue_balerma_capped_objective.m` start second searches from the saved
incumbents, capped at 20, 10, and 14 additional minutes, respectively.
The first-stage and continuation MAT files are retained. The stopping
summary adds each pair's generations, fitness evaluations and wall times;
its stop reason is the continuation's termination reason.

The optimizer creates one `StaciModel` per run. For every trial it changes the resident model's diameters and calls `solveHydraulics`; only chlorine objectives call `solveSteadyQuality('chemical')` during fitness evaluation. The other metrics are computed on the selected final design. No candidate writes an INP, report, or quality time history. Initial warm-start vectors are read before the GA, including prior archive vectors where present; every candidate is re-evaluated by STACI before acceptance. The INP link order and original diameters are read directly from the source INP by `wdn.staci_input_link_template` for final plotting data.

`run_staci_cost_entropy_front.m` uses `gamultiobj` on the same STACI fixed-load state. Its saved finite archive is not a globally certified Pareto frontier. `run_staci_ranking_studies.m` computes five pipe rankings, then nested subset GAs for four objectives. One cache file is saved for every objective, criterion and pipe count, so additional counts do not repeat earlier calculations. The cache signature checks network, objective, rank order and GA settings. For subsets smaller than the full pipe set, cached calculations remain valid if the full-network incumbent later improves; the full-set endpoint is refreshed from the new incumbent.

## Pipe failure outcomes

`run_staci_outage_studies.m` replays each final Anytown and Balerma design after closing each physical pipe once. The demand-driven diagnostic reports equal-node pressure and chlorine violation fractions. The pressure-driven replay uses zero minimum pressure, the nominal required pressure and exponent 0.5. Its total delivered-water service is `sum(min(delivered_i,requested_i))/sum(requested_i)`. Chlorine-compliant service counts only delivered demand at nodes with `c_i ≥ 0.2 mg/L`. All chlorine outcomes use STACI's direct stationary solution on the post-failure hydraulic state.

Balerma has bridge pipes whose failure disconnects junctions from every reservoir. `wdn.write_staci_connected_outage_input` generates a temporary INP containing exactly the source-connected part after each closure; the excluded nodes are assigned zero delivered demand and chlorine and count as pressure failures. This avoids an indeterminate hydraulic head in a source-free island. The surviving model is solved by STACI with `TRIALS 200`; that is a Newton iteration budget, not a changed physical parameter. Temporary INPs are created only in the outage replay, never in GA candidate evaluation. STACI's stationary quality solver treats a PDA junction with zero **delivered** demand and no incoming flow as stagnant even if its requested demand is positive. The paper's outage runner requires the corresponding STACI source update.

`run_pda_vulnerability_analysis('results_staci')` computes conditional scenario statistics from these saved outputs. For `N` enumerated pipe failures, “worst 10%” means exactly `ceil(0.1 N)` outages with the largest service deficit, averaged without interpolation: 4 of 38 in Anytown and 46 of 454 in Balerma. This is conditional outage severity, not an annual failure probability. No pipe failure rates or repair times are assigned.

## Independent engine check

`supplementary/validate_staci_final_designs.m` takes the exact full-precision diameter vector from each of the 15 final STACI MAT files, applies it to the same INP in EPANET 2.2, and compares all corresponding node heads, signed link flows and nodal chlorine against STACI. EPANET's quality simulation uses a 14-day horizon and five-minute quality step to approach the stationary field. The supplementary CSV reports design-wise maximum and arithmetic mean absolute differences, as well as Anytown anchor deviation and minimum chlorine at material-demand consumers. This validation is a cross-engine check for the specified fixed-load, first-order model; it does not cover time-dependent tanks or controls.

## Figures and minimum examples

`manuscript/figures/reproduce_all_figures.m` reads the saved STACI final results, ranking studies and Pareto archive. The analytical pressure-boundary example requires no solver. The four-pipe minimum examples use `wdn.evaluate_two_consumer_staci.m` for inverse sizing, flow and chlorine entropy, heads and concentration. Their `network_original.inp` contains the source chlorine and bulk reaction settings. The chlorine example's seeded GA and inverse sizing are in `make_two_consumer_chlorine_entropy_example.m`; the saved pair CSV includes all four nodal entropy contributions. Passing `false` replots that pair without a new GA.
