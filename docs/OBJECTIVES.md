# Objective definitions and sign conventions

MATLAB `ga` minimizes the returned fitness. The code negates maximized
quantities internally; saved tables report the physical quantities with
their usual signs. The nominal full-network Anytown and
Tanyimboh–Templeman searches share the 0.1–64 in diameter bounds, 10–120 m
assessment-junction pressure bounds, and a stationary 0.2 mg/L chlorine
floor at material-demand consumers. These constraints also apply to cost
and Todini searches. Anytown adds 215 ± 0.5 ft zero-flow pressure anchors
at R65/R165. The final Balerma R38-anchor designs use these same three
common limits. They additionally constrain the zero-flow R38 junction to
the head of its original 117 m reservoir; R43, R44 and R88 remain physical
nominal supplies. Failure replay restores all four physical reservoirs.

- **Cost (minimize):** sum of `230 * D.^0.48 .* L`, with the network-specific
  unit conversion in `network_config.m`.
- **Hydraulic entropy (maximize):** Tanyimboh–Templeman flow entropy using
  natural logarithms and nominal flow-throughput weighting. Artificial
  anchor connectors are excluded from the physical branching graph.
- **Branch-hop entropy (maximize):** the same local hydraulic splitting
  measure, weighted by `1/(1+b)`, where `b` counts undirected branching
  junctions from the nearest potential supply entry. A demand exit counts
  as a branch. The weight is frozen before optimization and does not use
  nominal flow directions.
- **Chlorine concentration (maximize):** `sum(C_i.^2)` over the configured
  quality-assessment junctions, computed from STACI's direct stationary
  chlorine solution. This is separate from the 0.2 mg/L consumer floor.
- **Chlorine entropy (maximize):** outgoing **chlorine-mass** branch
  probabilities at physical junctions, including consumer withdrawal as
  an exit branch. See `+wdn/staci_chlorine_entropy.m` and the paper's
  equation. This is not the older nodal-concentration multiplier.
- **Todini index (maximize):** the positive resilience index implemented
  in `+wdn/staci_todini_index.m`.

The six-design cross-evaluation divides cost by the smallest saved cost
and every maximized metric by the largest saved value. A diagonal value
of one means that the saved endpoint attains the best value **among those
six designs**. A finite GA run does not certify a global optimum.
