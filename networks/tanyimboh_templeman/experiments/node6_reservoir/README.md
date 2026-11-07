# Tanyimboh--Templeman pair with a reservoir at node 6

This is the separate experiment shown after the original equal-entropy
Tanyimboh--Templeman pair in Supplementary Material S1. The original network
and its saved results are unchanged.

`network_node6_reservoir.inp` keeps the original 50 m reservoir at node 8,
the prescribed injection at node 2, and the 10 m3/h demand at node 6. It
connects a new 35 m fixed-head reservoir R6 to node 6 through a fixed,
1 m long, 1000 mm diameter pipe. R6 is a physical source: it supplies about
4.10 m3/h. The connector is not a diameter decision, but its inflow is
counted as supply in the entropy calculation.

With MATLAB, STACI and the paper repository available as sibling directories,
run from this folder:

```matlab
run_node6_reservoir_pair
check_epanet_pair
plot_node6_reservoir_pair
```

The first function constructs B from A by shifting internal heads and
inverting the Hazen--Williams pipe-loss relation. A scalar root matches
stationary chlorine entropy. No genetic optimization is performed. It saves
the full-precision `design_A.inp` and `design_B.inp`, diameter and summary
CSVs, and the full numeric state in `pair_result.mat`. The second function
opens the two saved designs in EPANET 2.2 and checks hydraulic flows and
heads. The third generates the PNG and SVG Supplementary figure.

The saved pair has chlorine entropy 2.449346191037 nat in both layouts;
hydraulic entropy differs by 1.28e-7 nat and the largest STACI link-flow
difference is 6.63e-6 m3/h. These are feasible equal-objective designs,
not proven distinct global optima.
