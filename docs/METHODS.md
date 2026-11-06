# Computational methods and reproducibility

The [repository README](../README.md) gives the current execution order. The manuscript supplementary material gives the STACI hydraulic and stationary-quality equations, stopping records, and independent EPANET comparison.

## Fixed-load design model

Anytown uses `networks/anytown/input/network_anchor_replay.inp` and `network_config_anchor_replay.m`. The two auxiliary basin sites R65/R165 are zero-demand terminal junctions during nominal optimization: fixed pipes 78/80 have zero flow. The terminal heads at nodes 65/165 must lie within 215 ± 0.5 ft (equal to the adjacent network-side heads at zero flow). R10 and pump 82 deliver all 0.282644079872 m³/s of requested demand. The pump and fixed connectors are not diameter variables. The 38 physical pipes have continuous diameter bounds of 1–64 in. The minimum consumer pressure is 33 psi and the maximum is 165 psi. The config uses internal 0.02-ft anchor and 0.03-psi pressure margins to ensure independent EPANET replay stays within the stated physical limits; it uses the EPANET-consistent factor 2.30787 ft/psi.

The frozen branch-hop weights use undirected physical topology and the shortest count of branching junctions from potential supply entries 20, 60, and 160. A demand node with a single outgoing pipe also counts as a branch. Weight is `1/(1+b)`. Including 60 and 160 represents their possible role as supplies during failure, even though they do not supply nominal flow. Flow direction does not enter the weight. Only chlorine-directed searches enforce the nominal 0.2 mg/L floor, at consumers whose requested demand exceeds `π(0.010 m)^2(0.01 m/s)/4 = 7.854×10⁻⁷ m³/s`.

Anytown's demand pattern is frozen at its initial 0.7 multiplier. Hazen–Williams head loss, 1 mg/L source chlorine, bulk decay −1 day⁻¹, and zero wall decay are imported from the INP. There is no tank-level evolution or diurnal loading. Balerma and Tanyimboh–Templeman retain their own `network_staci_fixed_load.inp` and `results_staci/` studies; Balerma uses Darcy–Weisbach. Only the released `results_staci_anchor_replay/` supplies the current Anytown manuscript numbers; superseded nominal result variants were removed.

## Search and storage

`run_anytown_anchor_replay_optimizations.m` runs six objectives with STACI in memory. The released `cost_local_seed.mat` supplies a feasible warm start for the narrow pressure-anchor feasible region. Every candidate changes the resident STACI model's diameters, solves hydraulics, and computes direct stationary chlorine when needed; no candidate creates an INP or quality history. The 100-member GA has 150 stall generations, a 10,000-generation ceiling and a two-hour safeguard. Its actual stop generation, evaluations, time, seed, and constraint violation are in each MAT record and `ga_stop_six.csv`. Finite GA stopping is not proof of global optimality.

`run_anytown_anchor_replay_pareto.m` saves a finite nondominated cost versus branch-hop archive. `run_anytown_anchor_replay_rankings.m` calculates five pipe rankings and nested subset searches for four objectives. Each `(objective, criterion, K)` result is cached separately; adding larger K values does not rerun smaller subsets. For four criteria the K=1 GA found no feasible design. Their common K=2 two-pipe subset has a narrow feasible region that the initial GA missed; `find_anytown_anchor_replay_k2_seed.m` finds a feasible seed with bounded pattern search, after which each objective GA is run at K=2. The prior feasible diameter vector and its cross-evaluated metrics are retained at larger K whenever an independent GA returns a worse optimized objective. The original-diameter K=0 state is a plotting reference even if infeasible under the nominal design limits.

The ranked study yielded feasible 35-pipe branch-hop and chlorine-entropy
designs that exceeded the initial full-network GA endpoints. The one-time
`refine_anytown_anchor_replay_endpoints.m` continuation uses those vectors as
seeds; `refine_anytown_anchor_replay_hydraulic_entropy.m` then uses the improved
chlorine-entropy vector to improve hydraulic entropy. The original endpoints
were intermediate continuation stages; only their accepted final vectors are released.
The reported GA stop records and wall times describe the **final stages**.

## Failure replay

`run_anytown_anchor_replay_outages.m` transfers each saved nominal diameter vector without rounding to `network_physical_reservoirs.inp`. R65/R165 are again physical 215-ft reservoirs and can inject or absorb water. For each of the 38 physical pipe closures, the availability states are both auxiliary reservoirs, R65 only, and R165 only. The unavailable reservoir is isolated by closing its fixed connector; the available reservoir retains the original 215-ft head. R10/pump stays active. This yields 114 equally weighted cases per design, with no assigned outage probabilities.

Each case has demand-driven pressure/chlorine diagnostics and pressure-driven delivered-demand service. PDA uses zero minimum pressure, required pressure 33 psi, and exponent 0.5. Water service is `sum(min(delivered_i,requested_i))/sum(requested_i)`. Chlorine-compliant service includes only delivered demand at nodes with at least 0.2 mg/L. STACI solves stationary chlorine on each failed hydraulic state. `summarize_anytown_anchor_replay_vulnerability.m` computes conditional tail severity and ranking capture. Worst 10% means the average of the 12 largest deficits among 114 Anytown cases. These are conditional service measures, not annual reliability probabilities.

Balerma bridge failures can disconnect junctions from every reservoir. Its outage code writes a temporary source-connected INP, assigns zero service to the disconnected nodes, and uses a 200-iteration Newton budget. Temporary files occur only during failure replay, never in optimization candidates.

## Independent verification

`supplementary/validate_staci_final_designs.m` applies each exact final diameter vector to the same nominal INP in EPANET 2.2. It reports maximum and mean absolute node-head, signed link-flow, and chlorine differences in `supplementary/results/validation_anytown_anchor_replay/staci_epanet_anytown_anchor_replay_six.csv`. EPANET quality runs 14 days with five-minute steps to approximate the stationary field. All six nominal Anytown vectors meet the EPANET pressure and anchor-head limits. The benchmark applies to one fixed demand state and first-order chlorine model.

## Small-network branch-hop comparison

The Tanyimboh–Templeman Supplementary matrix uses the same six-objective panel order as Anytown. Its extra full-network branch-hop result optimizes all eight physical diameters. The frozen `1/(1+b)` weights start at physical supply entries 1 and 2; the EPANET fixed-head adapter `P_input_2` is excluded from the service graph. `tanyimboh_branch_hop_weights.m` computes weights from the undirected pipe graph and demand exits without a hydraulic solve. `run_tanyimboh_branch_hop_optimization.m` applies the common TT diameter bounds, 10-m pressure floor, and MATLAB GA settings. Its saved MAT, weights CSV, GA stop CSV, and six-design EPANET replay make the additional panel auditable.
