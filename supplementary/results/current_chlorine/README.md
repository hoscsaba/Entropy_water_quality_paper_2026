# Steady chlorine trajectories for Figure S1

These compact files reproduce the five panels of the supplementary steady-chlorine figure. Each network uses its current saved **branch-hop-weighted entropy design**. `trajectory.csv` gives the EPANET 2.2 hourly chlorine concentration (mg/L) at the plotted nodes; `steady.json` gives STACI's stationary concentration at the same nodes. The trajectories span 14 days at a fixed hydraulic load. The global convergence times in `convergence.csv` mark the first hour of a final, at-least-24-hour tail during which every network node stays within 0.0001 mg/L of its final range.

From MATLAB, add the parent `supplementary` directory to the path and run `plot_steady_chlorine_trajectories`. The plotter writes `steady_chlorine_trajectories.png` and `.svg` here. Solid curves are EPANET, dashed horizontal lines are STACI, and dotted vertical lines indicate global convergence when visible on the time axis.

The plotted nodes are TT 4/6/5, Anytown 20/100/170 and 140/80/90, and Balerma 179001/246/422 and 337/72/336. Anytown and Balerma use their respective pressure-anchor design models; the plotted profiles are computed for the nominal fixed-load designs, not pipe-failure simulations.
