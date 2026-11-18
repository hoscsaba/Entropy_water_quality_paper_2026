# Balerma: R38 pressure anchor, R44 physical reservoir

This run uses the original Balerma fixed-load hydraulic and reaction data.
During nominal optimization, R38 is replaced by a zero-demand junction; its
original total head of 117 m is imposed as a nonlinear constraint with the
same 0.5 ft tolerance used for the Anytown pressure anchors. R43 (127 m),
R44 (122 m), and R88 (112 m) remain physical fixed-head reservoirs. R38's two
existing connector pipes remain unchanged and may carry opposite signed
flows, but the junction has zero external net supply. The R38 chlorine
source is removed from the nominal input; R43, R44, and R88 retain their
1 mg/L source settings. All six objectives share the existing continuous
0.1–64 in diameter, 10–120 m consumer-pressure, and 0.2 mg/L consumer-
chlorine constraints. Branch-hop weights use all four *potential* reservoir
entries, including R38, as topology-only zero-hop roots.
The optimizer uses a 0.001 mg/L numerical margin inside the 0.2 mg/L
chlorine limit. This covers the small STACI–EPANET concentration discrepancy
found for a near-boundary Todini candidate; the published physical limit
remains 0.2 mg/L. EPANET validation is required for the final designs.

The input is generated from `input/network_staci_fixed_load.inp` by
`write_balerma_r38_anchor_input`. The original physical-reservoir input is
never modified. `network_config_r38_anchor` points to the new input and
uses its own result directory
`results_staci_r38_anchor_r44_physical_0p1_64in_v1/`.

In MATLAB R2026a with STACI's MATLAB MEX interface built:

```matlab
paper_root = '/absolute/path/to/Entropy_water_quality_paper_2026';
staci_root = '/absolute/path/to/staci';
mex_dir = fullfile(staci_root,'build-matlab','Matlab');
addpath(paper_root,fullfile(paper_root,'networks','balerma'));
for stage = ["seed","full"]
    run_balerma_r38_anchor(paper_root,staci_root,mex_dir,stage);
end
% Apply any justified feasible-seed/GA refinements described below, then:
adjudicate_balerma_r38_designs(paper_root,staci_root,mex_dir);
for stage = ["audit","validate","replay","topology"]
    run_balerma_r38_anchor(paper_root,staci_root,mex_dir,stage);
end
```

The `seed` stage uses a one-parameter bisection to construct a feasible
starting vector; it is **not** an optimized design. The `full` stage runs
the six independent MATLAB `ga` searches in the order cost, hydraulic
entropy, branch-hop entropy, chlorine concentration, chlorine entropy, and
Todini. Each objective has its own checked MAT checkpoint. Repeating `full`
skips completed objectives. The `audit` stage re-evaluates every final
vector with STACI and records the nominal source flows, R38 external flow,
anchor head, pressure range, and minimum consumer chlorine concentration.
It also exports the six-by-six raw and relative cross-evaluation tables and
the exact 454-by-six diameter vectors in both millimeters and inches.
The `validate` stage checks the final vectors independently in EPANET 2.2
and records maximum and mean head, flow, and chlorine differences.
For a single independent search, call the stage `full_` followed by its
objective key, for example `full_chlorine_entropy`. `audit_available` and
`replay_available` evaluate only objectives whose MAT results exist; the
complete `audit`, `validate`, and `replay` stages should be run after all
six searches finish.

The R38 head band is narrow in the 454-variable search. If a GA stops with
an infeasible population and merely returns a previously saved feasible
design, make a feasible starting population and retry that objective:

```matlab
create_balerma_r38_feasible_population(paper_root,staci_root,mex_dir, ...
    'chlorine_entropy',1500);
run_balerma_r38_refined_ga(paper_root,staci_root,mex_dir, ...
    'chlorine_entropy',1800);
% When the cost incumbent is dominated, continue a saved pipewise search:
create_balerma_r38_feasible_population(paper_root,staci_root,mex_dir, ...
    'cost',3000);
greedy_balerma_r38_cost_seed(paper_root,staci_root,mex_dir,5);
run_balerma_r38_refined_ga(paper_root,staci_root,mex_dir, ...
    'cost',1800);
% If a Todini candidate lies too close to the EPANET chlorine floor:
repair_balerma_r38_todini_seed(paper_root,staci_root,mex_dir);
run_balerma_r38_refined_ga(paper_root,staci_root,mex_dir, ...
    'todini',1800);
```

The first helper makes deterministic, in-memory coordinate perturbations
and accepts only candidates satisfying the same pressure, anchor, and
chlorine constraints. It records its seed search separately. The second
helper runs the same MATLAB GA from these feasible starts and saves its
result under `refined_ga/`. Compare the objective and verify the candidate
with EPANET before promoting it to the final MAT checkpoint.
For cost, `greedy_balerma_r38_cost_seed` then tries smaller pipe diameters
one pipe at a time, keeping only designs that satisfy all shared constraints.
It saves after every complete sweep, so a later run with a larger sweep
count continues without repeating finished sweeps. Its output is a GA warm
start and is labeled as such if GA finds no better feasible design. Near a
chlorine boundary, `repair_balerma_r38_todini_seed` can make a small P257
diameter adjustment before a guarded Todini rerun; the repaired vector is
also a GA warm start, not a substituted final result.

After all independent searches, `adjudicate_balerma_r38_designs` compares
their six feasible saved vectors under every objective. It assigns each
objective the best vector in that finite pool and archives the original
independent checkpoints in `pre_adjudication/`. The resulting diagonal of
`cross_evaluation_six_relative_to_best.csv` is exactly one by construction;
this selection does not establish global optimality. In this run, chlorine
concentration and chlorine entropy select the same vector. The archived
files and `cross_adjudication.csv` show where each final vector came from.
After adjudication, rerun `audit`, `validate`, and `replay` to regenerate
tables for the selected vectors. The replay cache is invalidated whenever
a selected diameter vector changes.

The Supplementary Material's ranked-subset and Pareto calculations are
separate from the six full-network searches. The original INP diameters
violate the new R38 head constraint, so `feasible_seed.mat` is their
common, anchor-feasible K=0 reference. Five rankings are frozen at that
reference design. Each subset releases K=0, 5, 20, 45, 70, or 90 of the
454 pipe diameters and retains the other values from the reference. Run
the six `rankings` objectives after the full-network designs; their cache
entries are individual `(objective, ranking, K)` MAT files and are reused
when adding larger subsets. The Pareto search then varies the first 90
pipes in the frozen volume ranking and keeps the other 364 at the same
reference values. Its selected displayed points are replayed under 448
protected-connector, all-four-reservoir cases apiece:

```matlab
run_balerma_r38_anchor(paper_root,staci_root,mex_dir,'rankings');
run_balerma_common_pareto(paper_root,staci_root,mex_dir, ...
    fullfile(paper_root,'networks','balerma', ...
    'results_staci_r38_anchor_r44_physical_0p1_64in_v1'));
result_dir=fullfile(paper_root,'networks','balerma', ...
    'results_staci_r38_anchor_r44_physical_0p1_64in_v1');
select_balerma_pareto_display_candidates(result_dir,20);
run_balerma_r38_pareto_replay(paper_root,staci_root,mex_dir);
```

The Supplementary Material figures use the saved results only. With
`manuscript/figures` on the MATLAB path, regenerate them with:

```matlab
figure_dir=fullfile(paper_root,'networks','balerma', ...
    'figures_staci_r38_anchor_v1');
make_balerma_r38_schematic(paper_root,figure_dir);
make_balerma_figures(result_dir,figure_dir);
make_balerma_pipe_only_figures(figure_dir,result_dir);
make_balerma_r38_failure_profiles(paper_root,result_dir,figure_dir);
make_balerma_common_pareto(paper_root,result_dir,figure_dir, ...
    'r38_anchor_protected_all_four');
% The published R38-unavailable front is a separate, saved Pareto study.
make_balerma_common_pareto(paper_root, ...
    fullfile(result_dir,'pareto_r38_unavailable_study'),figure_dir, ...
    'r38_anchor_r38_unavailable');
```

The SM tables are assembled without new hydraulic solves by
`python3 supplementary/build_balerma_r38_sm_tables.py RESULTS_DIR DRAFT_V3_DIR`.

If a ranked-subset GA finds a better feasible incumbent than the previous
454-pipe search, run `refine_balerma_r38_from_ranked` for that objective.
Then `finalize_balerma_r38_sm(paper_root,staci_root,mex_dir)` selects the
best feasible saved incumbents, re-evaluates them in the nominal model,
cross-checks the final six designs in EPANET, repeats their protected-pipe
PDA replay, and rebuilds the design and service figures. Original selected
vectors remain in `pre_rank_refinement/`; `refinement_selection.csv` records
which feasible candidate was retained. This finalization does not launch
another GA or rerun the cached ranking and Pareto searches.

The `replay` stage holds each optimized vector fixed, returns to the
untouched physical four-reservoir input, and performs PDA with one ordinary
pipe closed at a time. The direct reservoir connectors P5, P338 (R38),
P194, P223 (R43), P188 (R44), and P51 (R88) are protected: none appears in
the 448-pipe failure set. They remain in the graph even if their optimized
diameter equals the minimum bound. Their actual small hydraulic capacity
is still used. Each design's 448-case replay is checkpointed separately;
the summary and case tables are written after all six complete. A failed
STACI case is retried in EPANET PDA/EPS and marked in the checkpoint.
The `topology` stage separately records the percentage of consumers and
demand disconnected from all available reservoirs by each eligible pipe
failure. It gives a hydraulic-independent service ceiling for interpreting
the PDA results; it also includes each single-reservoir-unavailable state.

These results have a different nominal source model from the earlier
four-reservoir Balerma study. Its saved designs and tables must not be
combined with this run without an explicit model label.

## Completed full-network run (18 November 2026)

The final six nominal diameter vectors are in
`results_staci_r38_anchor_r44_physical_0p1_64in_v1/optimal_pipe_diameters_six_in.csv`.
The complete four-reservoir failure replay is in
`pda_four_reservoir_protected_cases.csv` (6 × 448 cases); its summary is in
`pda_four_reservoir_protected_summary.csv`. These are *single-pipe* outages
with all four reservoirs available and their direct connectors protected.
The minimum-water-service case is P170 for cost and chlorine concentration,
P166 for chlorine entropy, and P433 for hydraulic entropy, branch-hop
entropy, and Todini. P433
topologically disconnects 14.2534% of the original demand even with all
four reservoirs available. Nonconvergent STACI PDA cases in the final
replay are resolved with EPANET PDA/EPS; no case remains unresolved. The
independent nominal STACI–EPANET
checks are in `epanet_validation/staci_epanet_balerma_r38_anchor_six.csv`.
All six selected designs pass the 10–120 m pressure and 0.2 mg/L
consumer-chlorine limits in EPANET. Across the six final vectors, the
maximum node-head, pipe-flow, and node-chlorine differences are
0.001097 m, 0.018506 L/s, and 0.002236 mg/L, respectively.

The original independent GA checkpoints are preserved in
`pre_adjudication/`, and the formerly selected vectors in
`pre_rank_refinement/`. `refinement_selection.csv` and
`cross_adjudication.csv` record the finite-pool choices. The new full
hydraulic-entropy, branch-hop, chlorine-entropy, and Todini searches were
seeded with feasible 90-pipe ranking designs and give objective values
7.0595 nat, 28.0034 nat, 6.2746 nat, and 0.9220, respectively. The cost
and chlorine-concentration vectors are similar but distinct. No finite
search certifies global optimality. The final branch-hop design's worst
water service is 85.75%, compared with 83.48% for cost; the final
chlorine-entropy design falls to 62.21% on P166 failure.

## Additional R38-unavailable replay

This compound-failure replay holds all six final diameter vectors fixed
and removes the physical R38 reservoir **and** its P5/P338 connectors.
R43, R44, and R88 retain their original fixed heads; their four direct
connectors remain protected. The same 448 ordinary pipes fail one at a
time under PDA. A separate source-only PDA case has R38 absent but no
additional pipe failure. The outage input writer checks that R38 is
absent from the connected hydraulic graph and all three remaining
reservoirs are present.

```matlab
run_balerma_r38_unavailable_replay(paper_root,staci_root,mex_dir);
make_balerma_r38_unavailable_failure_profiles(paper_root,[],[]);
```

The case and summary CSV files, plus per-design checkpoints, are in
`results_staci_r38_anchor_r44_physical_0p1_64in_v1/r38_unavailable_protected/`.
The SM tables are generated without new hydraulic solves by
`python3 supplementary/build_balerma_r38_unavailable_sm_tables.py RESULTS_DIR DRAFT_V3_DIR`.
The 6 × 448 cases all have final results; 42 of the chlorine-concentration
design's cases required the documented EPANET PDA/EPS rescue. This is a
different stress-test boundary, not a new nominal optimization. With R38
unavailable, the Todini design has the largest mean and minimum water
service (99.15% and 84.84%). The latter matches the topological ceiling
under P419 failure; the branch-hop design has 76.98% minimum service.

## Cost–branch-hop Pareto study with R38 unavailable during failure replay

The multiobjective GA uses the **nominal R38-anchor model** and the same
fixed top-90 volume-ranked pipe subset as the all-four-reservoir study.
It minimizes cost and maximizes branch-hop entropy under the common
nominal pressure and consumer-chlorine constraints. Failure service is
evaluated *after* the search and does not enter either Pareto objective.
The separate study directory prevents the previous all-four-reservoir
archive from being overwritten.

```matlab
study_dir=run_balerma_r38_unavailable_pareto( ...
    paper_root,staci_root,mex_dir);
files=finalize_balerma_r38_unavailable_pareto( ...
    paper_root,staci_root,mex_dir);
```

The first call repeats the seeded `gamultiobj` search (population 120,
at most 250 generations, fixed random seed) and chooses 20 nominally
non-dominated designs at roughly uniform normalized-objective arclength.
The second replays each selected diameter vector with R38 and P5/P338
unavailable and the other three physical reservoirs connected. Their
four direct connectors remain protected; each design is tested for all
448 eligible ordinary single-pipe failures under PDA. A diameter-checked
checkpoint is saved per point, so interrupted replays can be resumed.
The table `pareto_failure_service.csv` reports both worst-service KPIs.
In the figure, color represents worst delivered-water percentage and
circle area increases as worst chlorine-compliant service decreases.
The completed search reached 250 generations and 30,001 objective
evaluations in 31.3 minutes. It saved 98 candidates, including 93
nondominated designs, and reproduced the previous nominal archive exactly
(maximum diameter and objective differences: zero). All 20 selected
designs completed all
448 outage evaluations (8,960 cases in total); four individual cases
required EPANET PDA/EPS rescue. P506 is the worst outage for both service
measures at every selected point. Worst water service ranges from 46.09%
to 51.32%; worst chlorine-compliant service ranges from 45.51% to 51.15%.
These are restricted-subset designs, so their range should not be
interpreted as the attainable range of the six full-network searches.
