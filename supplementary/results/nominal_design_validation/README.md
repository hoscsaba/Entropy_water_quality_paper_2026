# Independent nominal-design audit

`validate_reported_nominal_designs.m` checks the exact saved diameter vectors used by the current main paper and Supplementary Material. It reads six final single-objective designs, the plotted ranked-subset MAT arrays, both full TT and Anytown cost–branch-hop Pareto archives, and the 20 selected Balerma Pareto points. The current manifest has 1,369 rows. Exact duplicate vectors within one network reuse the first independent result.

This audit is a required post-search release step for every nominal vector shown in a figure or table. Run it after finalizing the MAT files and review the status of every row before releasing results. It is deliberately outside the GA fitness loop and does not validate pressure-driven pipe-failure replays.

For each unique vector the program creates **fresh** EPANET 2.2 and STACI models from the same nominal fixed-load INP, sets the same design-link diameters in each model, runs hydraulics and chlorine, and matches node/link results by ID. It reports maximum and mean absolute head, **signed** flow and chlorine differences. Consumer chlorine is reported separately from all-node chlorine because zero-demand stagnant nodes can differ without affecting the consumer constraint. EPANET pressure, chlorine, diameter and pressure-anchor limits are checked independently.

For the TT network, STACI's hydraulic Newton tolerances are set to 10⁻¹¹ m head and 10⁻¹² kg/s mass residual, matching the strict post hoc evaluation used for the reported TT values. Anytown and Balerma retain their saved-model solver settings. EPANET uses the unchanged INP settings for each network.

When this file is placed in `supplementary/` of the paper checkout, a smoke test is:

```matlab
staci_root = '/absolute/path/to/staci';
validate_reported_nominal_designs(staci_root, [], ...
    fullfile(tempdir, 'nominal_audit'), 2);
```

Use `Inf` for the fourth argument to complete or resume the audit. The fifth argument optionally filters to one or more network IDs. While this script is staged in `/private/tmp`, pass the paper checkout as the sixth argument because `mfilename` cannot derive it there.

The CSV contains repo-relative `SourceMAT` paths and `FreshModel=1` for independent runs. `SameAsCaseID` identifies an identical vector whose fresh result was reused. The compact MAT checkpoint stores row results and a SHA-256 digest of the rebuilt source manifest; changes to saved vectors or source-file stamps are rejected on resume. Results are checkpointed every 25 rows and at each network boundary.

Status meanings:

- `ok`: numerical agreement at the stated thresholds and the EPANET design constraints pass for a saved feasible row.
- `compare_only`: the saved ranked-subset row was already marked infeasible or is a reference case; numerical agreement is checked, but physical feasibility is not claimed.
- `discrepancy`: maximum absolute head exceeds 0.1 m, signed flow exceeds 0.01 L/s, or material-consumer chlorine exceeds 0.01 mg/L. Inspect `MaxHeadNodeID`, `MaxFlowLinkID` and both engine values.
- `epanet_infeasible`: the saved row is labelled feasible, but EPANET violates a 10–120 m pressure bound, the 0.2 mg/L consumer chlorine floor, a prescribed anchor-head tolerance, or a diameter bound beyond numerical tolerance.
- `error`: a model or data integrity check failed; the error text is recorded and the row is retried on resume.

The numerical agreement thresholds are audit flags, not optimization tolerances. Near-zero head losses can make flow splits ill-conditioned even when head and pressure agree closely; retain and discuss such flags rather than raising thresholds without hydraulic justification. The audit does not replay pipe-failure PDA scenarios.

## Released nominal audit

The current CSV covers all 1,369 displayed nominal vectors. An independent matched EPANET/STACI solve was made for each of the 1,054 distinct vectors; duplicate vectors inherit the first checked result. The feasible Anytown K=0 candidate uses P6 = 14.88 in, so every one of its 510 ranked-subset rows is now an actual feasible design. No model call failed.

| Network | `ok` | `discrepancy` | `epanet_infeasible` |
|---|---:|---:|---:|
| Tanyimboh–Templeman | 371 | 0 | 1 |
| Anytown | 773 | 18 | 0 |
| Balerma | 132 | 74 | 0 |
| **Total** | **1,276** | **92** | **1** |

All 18 final single-objective designs satisfy the EPANET constraints. The six TT and six Anytown final designs also pass the numerical agreement thresholds. The Balerma branch-hop and Todini final designs have small signed-flow flags (0.0185 and 0.0114 L/s), while their maximum consumer-chlorine differences are 0.00224 and 0.000831 mg/L. These flags are retained in the CSV.

All 791 Anytown rows pass the independently checked pressure, chlorine, diameter, and pressure-anchor limits. Its 18 numerical flags occur in ranked subsets: each exceeds the 0.01 L/s signed-flow audit threshold, but the largest difference is 0.0456 L/s. The maximum head and material-consumer chlorine differences over Anytown are 0.000303 m and 0.000679 mg/L. The repaired K=0 baseline itself is `ok`: its maximum head, signed-flow, and consumer-chlorine differences are 1.66×10⁻⁵ m, 0.000172 L/s, and 0.000400 mg/L.

All 96 TT and 275 Anytown Pareto rows are `ok`. Eighteen of the 20 selected Balerma Pareto rows are `ok`; archive indices 58 and 52 have signed-flow differences of 0.0108 and 0.0164 L/s, respectively, while both pass the EPANET constraints. Among the 74 Balerma numerical flags, two ranked subsets also exceed the 0.01 mg/L consumer-chlorine agreement threshold: chlorine-concentration/nodal-entropy at K=20 (0.0123 mg/L) and Todini/nodal-entropy at K=20 (0.0217 mg/L). The largest Balerma link-flow difference is 0.2101 L/s. No case in any network exceeds the 0.1 m head-agreement threshold.

One TT cost/nodal-entropy ranked subset at K=6 is `epanet_infeasible`: EPANET exceeds a pressure limit by 0.000286 m while the saved STACI constraint violation is zero. This near-boundary exception is reported rather than rounded away; it does not affect the six final TT designs.

The TT Todini and other very large-diameter layouts can have head differences of order 10⁻⁶ m across a pipe. Their solved flow splits depend on finite hydraulic tolerances; repeated solves on a resident model produced larger, history-dependent differences than fresh-model replays. The released CSV therefore uses fresh models and the same strict TT STACI tolerance as the corrected TT cross metrics. Some Anytown ranked layouts also contain nearly stagnant links for which small solver differences change the local split. The audit verifies the saved vectors against independent EPANET runs; it does not establish identical cross-evaluated objective values to arbitrary numerical precision or replay pipe-failure PDA states.
