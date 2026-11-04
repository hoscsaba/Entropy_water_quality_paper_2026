# Objective definitions and sign conventions

The shared functions always return physical, positive quantities. MATLAB `ga`
minimizes, so `wdn.objective_value` negates only quantities that are maximized.
Saved result tables never contain this optimizer sign convention.

- **Cost:** `sum(230 * D.^0.48 .* L)`, with network-specific unit conversion
  defined in `network_config.m`.
- **Hydraulic entropy:** natural-log Tanyimboh–Templeman flow entropy evaluated
  on the physical network graph. Artificial EPANET pressure-anchor adapters are
  excluded and their flow is collapsed onto the adjacent physical node.
- **Chlorine concentration:** sum of squared terminal node concentrations,
  `sum(C.^2)`, over the configured quality nodes after the 48 h EPANET run.
- **Chlorine entropy:** the same flow-entropy expression with terminal node
  chlorine concentration as the node multiplier (numerically normalized to the
  1 mg/L source concentration in the reported calculations). The source-mixing
  term is weighted likewise. This is not a downstream-concentration
  renormalization of each outgoing branch probability.
- **Todini index:** the positive resilience index returned by
  `wdn.todini_index`.

Cost is minimized; all other metrics are maximized. Cross-evaluation reports
cost relative to the smallest saved cost and every maximized metric relative to
the largest saved value. A valid set therefore has ones on the diagonal (ties
are allowed).
