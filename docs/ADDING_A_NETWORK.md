# Adding another EPANET network

1. Copy an immutable INP file to `networks/<id>/input/network_original.inp`.
2. Copy the closest `network_config.m` and change every physical/model setting
   explicitly. In particular, list design pipes, fixed hydraulic equipment,
   entropy-excluded adapters, assessment nodes, source nodes, unit conversions,
   pressure limits, chlorine source and reaction settings, and the fixed load.
3. Do not infer physical pipes from all EPANET links when pumps, valves, virtual
   pressure anchors, or compatibility connectors are present.
4. Add a small network-specific driver that calls the shared `+wdn` functions;
   do not copy objective formulas into the network folder.
5. Run one unmodified-design evaluation and manually verify link/node counts,
   units, source concentrations, pressures, and objective signs.
6. Run the five objectives, then `wdn.write_cross_evaluation`. A diagonal check
   failure means the affected objective must be resumed with all saved elites;
   it must not be hidden by rounding the table.
7. Validate nominal feasibility and then run the independent pipe-failure test.

For a boundary used only to prescribe head, use the article's pressure-anchor
treatment: model it as a zero-demand junction with no supply or withdrawal,
and constrain its head in the optimizer. Exclude its fixed compatibility link
from the physical entropy graph and outage set. Keep a true water source as a
reservoir; a real storage tank needs a time-dependent model.

Keep runtime files, absolute paths, user-specific toolbox locations, and dated
external seeds out of the release. Store compact warm starts by link ID inside
the network folder, document their provenance, and record whether an incumbent
was selected over the optimizer's returned individual.
