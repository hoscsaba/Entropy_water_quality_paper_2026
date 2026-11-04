# Reproducible methods and implementation details

The main article retains the definitions and assumptions needed to interpret its results. This document records the software, scripts, model parameters, validation checks, and implementation choices needed to reproduce them.

## Software and first run

The reported calculations used MATLAB R2026a (26.1), Global Optimization Toolbox, Optimization Toolbox, EPANET 2.2, and EPANET–MATLAB Toolkit 2.2.6.5 on Apple Silicon macOS. The bundled arm64 EPANET library was built from OpenWaterAnalytics EPANET v2.2, commit `4d8d82ddc260fce216af9321fc3d9a4646ac6827`. A system toolkit can be selected with `WDS_EPANET_TOOLKIT`.

From the repository root in MATLAB:

```matlab
startup
validate_environment
run_smoke_test
validate_saved_results
reproduce_all_figures
export_manuscript_tables
```

The first three commands verify the installation and replay all 15 saved production designs through EPANET. The last two regenerate article figures and numeric table inputs without genetic optimization. `manuscript/MANIFEST.md` maps every active figure and table to its script and saved input.

## Figure 1: pressure-only basin and spurious flow entropy

Run `startup; make_pressure_anchor_mwe_figure` from the repository root. This
is analytic, without EPANET or optimization. Consumer D always receives one
flow unit. The signed basin flow `x` is positive when J charges B, and
negative when B supplies J. The source S supplies `1+x`, so `-1 <= x <= 1`
keeps its flow nonnegative. For `x < 0`, a model that counts B as an external
source assigns shares `(1+x,-x)` and entropy
`S_counted = -(1+x)*ln(1+x)-(-x)*ln(-x)`. For `x > 0`, a model that counts
charging as a service branch assigns junction probabilities
`(1/(1+x),x/(1+x))` and their binary entropy. The zero-log-zero limit
applies at `x=-1,0`. Checks in the script verify `S_counted(0)=0` and
`S_counted(-0.5)=S_counted(1)=ln(2)=0.69314718` nat. The negative branch
represents actual source diversity only if B is a genuine supply; the
positive branch is a non-service charging reward. The script exports
`manuscript/generated/figures/pressure_anchor_mwe.png` and `.svg`.

## Looped two-consumer examples: diameter non-uniqueness

Both scripts read the same four-pipe INP through EPANET 2.2. The pipes are
P0=S--J, P1=J--D1, P2=J--D2, and P3=D1--D2. All lengths are 3000 m,
Hazen--Williams C is 120, source head is 50 m, junction elevations are
zero, and demands are 0.8 and 1.3 L/s. For cross flow `x=Q3` from D1 to D2,
continuity gives `(Q0,Q1,Q2,Q3)=(2.1,0.8+x,1.3-x,x)` L/s. Hydraulic entropy
is the three-way entropy of normalized path flows `(0.8,x,1.3-x)/2.1` and
has its maximum at `x=0.65` L/s: `S_flow=1.093619622743` nat. The Figure 2
script fixes P0/P1/P3 at 100/80/60 mm and solves P2 as 51.5819149 mm.
Doubling the full diameter vector gives (200,160,103.1638298,120) mm;
EPANET returns the same four flows and entropy. D1/D2 heads are
40.8159/35.7617 m and 49.6862/49.5134 m. Both exceed the 20 m minimum.

`make_two_consumer_chlorine_entropy_example` sets 1 mg/L at S, -1/day bulk
decay, 48 h duration, five-minute quality step, 40--200 mm diameter bounds,
minimum 20 m consumer heads and minimum 0.2 mg/L terminal chlorine at both
consumers. A MATLAB GA (seed 1993, population 80, at most 100 generations,
pressure/chlorine penalties) gives a best-known feasible chlorine entropy
near 0.977594255 nat. Holding its P0/P1 diameters and P3 flow fixed, the
script varies P3 and uses an EPANET root solve for P2; the first and last
feasible candidates form the saved pair. The current saved run has diameters
A `(70.11595468,79.51318359,56.09366586,70)` mm and
B `(70.11595468,79.51318359,60.08194109,200)` mm. Both have flows
`(2.1,1.419714,0.680286,0.619714)` L/s and chlorine entropy
`0.977594225312` nat to numerical precision. D1 residual is 0.833446 mg/L
in both; D2 residual is 0.750619 versus 0.491104 mg/L. The minimum
consumer heads are 21.6043 and 23.7748 m respectively. The nodewise
chlorine-entropy contributions (S, J, D1, D2) are
`(0, 0.5915925488, 0.3860016765, 0)` nat in both designs; they sum to
`0.9775942253` nat. The equal total is therefore not a cancellation of
changed node terms. The result CSVs now include all four nodal contributions. In these two figures, `H` denotes hydraulic head, `S_flow` and `S_Cl` denote the total entropies, and `S_i` denotes a local nodal contribution.
The MATLAB figure helper writes both PNG and SVG files, with per-node
consumption, head, chlorine where applicable, and entropy contribution in
labels beside the corresponding nodes. The panel titles report the total entropy.

With positive D1--D2 flow, only J and D1 have local flow splits. The
implemented chlorine entropy weights these local split entropies by the
respective node concentration; terminal D2 has no local entropy term. Once
P0/P1 and the full flow vector are held fixed, changing P3 and compensating
with P2 changes D2 residence time and pressure but not the objective.
This is a non-symmetry, near-optimal feasible family. The GA results do not
prove that the exact global maximum is non-unique. The script writes
`two_designs.csv`, `chlorine_entropy_pair.csv`, and
`chlorine_entropy_search.mat` in the mini-network results directory, then
exports the two PNG/SVG figures. Calling the chlorine script with `false`
replots the saved pair without a GA search.

## Nominal optimization

Each `networks/<id>/network_config.m` is the authoritative source for bounds, sources, pressure limits, chlorine settings, and GA options. The Tanyimboh–Templeman run has eight continuous pipe variables, population 100, up to 500 generations, stall limit 100, and seed 1993. Anytown has 38 variables; Balerma has 454. Both larger models use population 100, up to 100 generations, stall limit 30, seed 1993, function tolerance `1e-6`, and raw constraint tolerance `5e-5`. Fitness evaluations are sequential (`UseParallel=false`) because one EPANET object is mutable.

The five single-objective runs are cost minimization and maximization of hydraulic entropy, terminal squared chlorine concentration, chlorine entropy, and Todini's index. Each compatible saved feasible design is reused as a warm-start elite. The synchronized archive checks all five metrics on all saved incumbents and assigns each objective its best known feasible design. Raw GA returns remain in audit fields; identical labels can select the same design. The Anytown two-objective `gamultiobj` figure is an initial feasible archive, not a converged global frontier.

Chlorine is evaluated at 48 h with 1 mg/L source concentration and bulk reaction coefficient `-1` in the model's EPANET units. Anytown has a 3 h hydraulic and quality step; Balerma has a 1 h step. These were retained after regression checks: coarse steps changed terminal concentrations. Static EPANET quality settings are applied once; only the terminal state is transferred to MATLAB. This reduced fitness time without changing the validated model. Full benchmark scripts remain available in the repository for performance reproduction.

## Boundary roles

In Anytown, reservoir 10 is the true external source. Nodes 65 and 165 prescribe 215 ft target heads with a 0.5 ft tolerance but are zero-demand junctions in the optimization model. Their virtual adapters are fixed and excluded from the 38 physical design variables, cost, and entropy graph. A finite operational tank requires a time-dependent storage model instead of this pressure-only treatment. See `docs/OBJECTIVES.md` for the metric definitions.

## Demand-driven failure diagnostics

`run_anytown_stress_test` and `run_balerma_stress_test` close each physical design pipe once and evaluate pressure and terminal chlorine at the configured junctions. Their pressure- and chlorine-violation fractions give each failure–node pair equal weight. EPANET demand-driven analysis enforces specified withdrawals even when pressure is deficient, so these fractions are diagnostics rather than delivered-demand estimates.

## Pressure-driven service replay

Run `run_pda_service_study` after `startup`. It reads the five saved designs per network and does not run an optimizer. Identical Balerma design vectors are evaluated once and their results reused under both objective labels. The replay uses EPANET 2.2 pressure-driven demand with minimum pressure zero, required pressure equal to the network's nominal minimum (33 psi Anytown, 10 m Balerma), and pressure exponent 0.5. Every physical design pipe is closed in turn.

For each design, requested demand is read from the intact demand-driven EPANET state, so input demand multipliers and patterns are respected. The delivered amount is read from the pressure-driven result after each outage. The toolkit `getNodeDemandDeficit` value is not used: in the tested configuration it did not return a usable positive unmet-demand quantity. The EPANET toolkit sometimes returns nodal demand slightly above the specified request in Balerma. Such excess cannot be counted as additional service: it is recorded in `OverdeliveryNodeCount` and `MaxOverdelivery` and then capped at the requested demand. The 48 h terminal chlorine state is recomputed for each outage. A failed or nonfinite scenario is recorded as zero service, with its error message retained in the scenario CSV.

For failed pipe `f`, both fractions use total requested demand in the denominator:

- Delivered-demand service: `sum(delivered_i) / sum(requested_i)`.
- Chlorine-compliant service: `sum(delivered_i * (chlorine_i >= 0.2 mg/L)) / sum(requested_i)`.

`networks/<id>/results/pda_service_summary.csv` reports the mean across equally weighted single-pipe outages and the worst outage. `pda_service_scenarios.csv` retains each failure. These are deterministic N−1 service fractions, not annual reliability probabilities. Pipe-failure rates, repair durations, and operating-state probabilities would be required for an expected-reliability estimate. The current demand-weighted chlorine fraction can differ sharply from an equal-node low-chlorine fraction when low-chlorine nodes carry little or no requested demand.

## Conditional outage vulnerability and ranking validation

After `run_pda_service_study`, run `run_pda_vulnerability_analysis`. This reads only the saved scenario CSVs and the full `pipe_rankings.mat` files. For each design and failed pipe, the hydraulic deficit is `1 - DeliveredDemandFraction`; the joint water-and-chlorine deficit is `1 - QualityCompliantDemandFraction`; their difference is the chlorine-only loss. The latter is expressed in percentage points of total requested demand, not as a fraction of delivered water.

For `N` equally weighted physical-pipe failures, the **worst 10%** is precisely the `K = ceil(0.10*N)` largest scenario deficits, averaged without interpolation. Thus `K=4` of 38 in Anytown (10.53% of tested scenarios) and `K=46` of 454 in Balerma (10.13%). The worst 10% for joint service is selected independently of the worst 10% for hydraulic service; they need not contain the same pipes. The below-95% statistic counts scenarios with service **strictly** below 95%, divided by `N`. These are proportions of enumerated N−1 cases, not annual failure probabilities.

`pda_vulnerability_summary.csv` stores those statistics for all five saved objective labels. `pda_pipe_criticality.csv` stores per-pipe hydraulic and joint deficit and the consequence rank for each design. `pda_ranking_validation.csv` compares every pre-existing selection criterion with the independently simulated outage consequence: Spearman correlation uses midranks for tied consequences, while `TopTenPercentCapturedDeficitPercent` is the share of the sum of all N−1 deficits attributable to the criterion's first `K` pipes. `TopTenPercentCriticalPipeOverlap` is the count shared with the highest-consequence `K` pipes. The selection rankings were originally computed about a common feasible reference network, whereas outage consequences are evaluated separately on each saved optimized design. Consequently, this is a predictive transfer check, not a ranking recalibrated to each design. A ten-percent share is the equal-impact reference expectation; highly unequal pipe consequences can make capture fractions much larger.

## Related reliability and resilience measures

The stored N−1 deficits characterize immediate, conditional vulnerability. Hashimoto, Stedinger and Loucks distinguish this consequence magnitude from failure probability (reliability) and recovery speed (resilience), DOI `10.1029/WR018i001p00014`. Ciaponi, Franchioli and Papiri explicitly weight pipe-outage states by failure probabilities, DOI `10.1061/(ASCE)WR.1943-5452.0000184`. Crozier, Lence and Weijs describe water-supply resilience using performance curves and restoration, DOI `10.1080/23789689.2024.2340378`. The present data contain neither pipe-specific failure rates nor repair and control trajectories. Therefore a probability-weighted availability, restoration time, or area under a recovery curve cannot be estimated as a measured property of these benchmarks. Such indicators would require the relevant asset and operating data; assigning arbitrary rates would only define a sensitivity scenario.

A demand-weighted fraction of customers receiving their full request, severity below the 0.2 mg/L chlorine threshold, and spatial equity of unmet demand are useful next indicators. They require storing nodal PDA demand and concentration for every scenario, rather than just the aggregate scenario CSV. A diurnal demand sensitivity is also possible by replaying the saved designs under calibrated operating patterns, while preserving physical tank and control behavior.

## Validation and limits

`validate_saved_results` accepts at most `1e-6` relative metric difference against the stored designs and checks raw pressure feasibility. The pressure-driven replay uses the same pipe failures and chlorine threshold as the original diagnostics. Nominal optimization remains demand-driven and uses one fixed hydraulic load per network. The pressure-driven service replay changes only the evaluation model; it does not retroactively change the optimized designs. Diurnal demand, uncertainty in reaction coefficients, failure frequencies, and repair duration remain outside the reported results.
