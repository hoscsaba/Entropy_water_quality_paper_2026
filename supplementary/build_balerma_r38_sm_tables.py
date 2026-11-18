#!/usr/bin/env python3
"""Build the Balerma R38-anchor Supplementary Material tables from saved CSVs.

Usage: python3 build_balerma_r38_sm_tables.py RESULT_DIR DRAFT_DIR
No simulation or optimization is performed. Each table is regenerated from
the six final nominal vectors and the 6 x 448 protected-connector PDA cases.
"""
from __future__ import annotations

import csv
import math
import pathlib
import sys

result_dir = pathlib.Path(sys.argv[1])
output_dir = pathlib.Path(sys.argv[2])
output_dir.mkdir(parents=True, exist_ok=True)
keys = ["cost", "hydraulic_entropy", "branch_hop_weighted_entropy",
        "chlorine_concentration", "chlorine_entropy", "todini"]
names = {"cost": "Cost", "hydraulic_entropy": "Flow entropy",
         "branch_hop_weighted_entropy": "Branch-hop entropy",
         "chlorine_concentration": "Cl concentration",
         "chlorine_entropy": "Cl entropy", "todini": "Todini"}
metric_keys = ["Cost", "HydraulicEntropy", "BranchHopEntropy",
               "ChlorineConcentration", "ChlorineEntropy", "Todini"]
metric_heads = [r"Cost [$10^6$]", r"$S_Q$", r"$S_b$",
                r"$J_{\mathrm{Cl}}$", r"$S_{\mathrm{Cl}}$", "Todini"]


def read(name: str) -> list[dict[str, str]]:
    with (result_dir / name).open(newline="") as handle:
        return list(csv.DictReader(handle))


def fmt(value: float | str, places: int = 3) -> str:
    return f"{float(value):,.{places}f}"


def short(value: float | str) -> str:
    return f"{float(value):.3g}"


def best(value: float | str, optimum: float, *, minimum: bool = False,
         places: int = 3) -> str:
    x = float(value)
    cell = fmt(x, places)
    if math.isclose(x, optimum, rel_tol=1e-10, abs_tol=1e-10):
        return r"\textbf{\textit{" + cell + "}}"
    return cell


def write_table(filename: str, label: str, caption: str,
                headers: list[str], body: list[list[str]], *,
                widths: str | None = None) -> None:
    widths = widths or "l" + "r" * (len(headers) - 1)
    lines = [r"\begin{table}[p]", r"\centering\footnotesize",
             r"\setlength{\tabcolsep}{3pt}",
             r"\caption{" + caption + "}", r"\label{" + label + "}",
             r"\begin{tabular}{" + widths + "}", r"\toprule",
             " & ".join(headers) + r" \\", r"\midrule"]
    lines.extend(" & ".join(row) + r" \\" for row in body)
    lines.extend([r"\bottomrule", r"\end{tabular}", r"\end{table}"])
    (output_dir / filename).write_text("\n".join(lines) + "\n")


raw = read("cross_evaluation_six_raw.csv")
relative = read("cross_evaluation_six_relative_to_best.csv")
adjudication = {r["Objective"]: r for r in read("cross_adjudication.csv")}
refinement = {r["Objective"]: r for r in read("refinement_selection.csv")}
validation = {r["objective"]: r for r in
              read("epanet_validation/staci_epanet_balerma_r38_anchor_six.csv")}
service = {r["Objective"]: r for r in
           read("pda_four_reservoir_protected_summary.csv")}
anchor_audit = {r["Objective"]: r for r in read("nominal_anchor_audit.csv")}
cases = read("pda_four_reservoir_protected_cases.csv")
assert len(raw) == len(relative) == len(adjudication) == len(refinement) == len(validation) == len(service) == len(anchor_audit) == 6
assert len(cases) == 6 * 448
assert [r["OptimizedFor"] for r in raw] == keys

body = []
for row in raw:
    values = [float(row[k]) / (1e6 if k == "Cost" else 1)
              for k in metric_keys]
    body.append([names[row["OptimizedFor"]]] + [fmt(v) for v in values])
write_table("balerma_r38_raw.tex", "tab:balerma_r38_raw",
            "Balerma nominal objective values for the six R38-anchor designs. "
            r"Cost is in $10^6$ relative units; the entropy scores are in nat; "
            r"$J_{\mathrm{Cl}}$ is in $(\mathrm{mg/L})^2$.",
            ["Design"] + metric_heads, body)

body = []
for row in relative:
    body.append([names[row["OptimizedFor"]]] +
                [best(row[k], 1.0, places=4) for k in metric_keys])
write_table("balerma_r38_relative.tex", "tab:balerma_r38_relative",
            "Balerma nominal objective values relative to the best of the six "
            "saved R38-anchor designs. Cost is divided by the minimum; each "
            "maximized score is divided by its maximum. Bold italics mark "
            "the best value before rounding.",
            ["Design", "Cost", r"$S_Q$", r"$S_b$",
             r"$J_{\mathrm{Cl}}$", r"$S_{\mathrm{Cl}}$", "Todini"], body)

body = []
for key in keys:
    r = validation[key]
    source = refinement[key]["SelectedFrom"]
    start = "Ranked $K=90$" if "_from_ranked.mat" in source else "Prior saved"
    body.append([names[key], fmt(r["ga_generations"], 0),
                 fmt(r["ga_wall_seconds"], 1), start])
write_table("balerma_r38_ga.tex", "tab:balerma_r38_ga",
            "Balerma full-network genetic-search stopping records. "
            "Four searches started from feasible ranked-subset vectors; "
            "their times exclude the preceding ranking work. "
            "Prior saved denotes an earlier feasible selected vector.",
            ["Objective", "Gen.", "GA time (s)", "Start"], body,
            widths="lrrl")

body = []
for key in keys:
    r = validation[key]
    body.append([names[key]] + [short(r[k]) for k in
                ["max_abs_head_m", "mean_abs_head_m",
                 "max_abs_flow_Lps", "mean_abs_flow_Lps",
                 "max_abs_chlorine_mgL", "mean_abs_chlorine_mgL"]])
write_table("balerma_r38_epanet.tex", "tab:balerma_r38_epanet",
            "Independent STACI--EPANET 2.2 differences for the six final "
            "Balerma R38-anchor nominal designs: maximum and mean absolute "
            "differences in nodal total head (m), signed pipe flow (L/s), "
            "and steady chlorine residual (mg/L).",
            ["Design", r"$\Delta H_{\max}$", r"$\overline{|\Delta H|}$",
             r"$\Delta Q_{\max}$", r"$\overline{|\Delta Q|}$",
             r"$\Delta c_{\max}$", r"$\overline{|\Delta c|}$"], body)

body = []
for key in keys:
    r = anchor_audit[key]
    assert abs(float(r["R38ExternalFlow_m3s"])) < 1e-12
    assert abs(float(r["R38ConnectorBalance_m3s"])) < 1e-12
    body.append([names[key], fmt(r["R38Head_m"], 3),
                 fmt(1000 * float(r["R38ExternalFlow_m3s"]), 3),
                 fmt(1000 * float(r["R38ConnectorBalance_m3s"]), 3),
                 fmt(1000 * float(r["R43Supply_m3s"]), 1),
                 fmt(1000 * float(r["R44Supply_m3s"]), 1),
                 fmt(1000 * float(r["R88Supply_m3s"]), 1)])
write_table("balerma_r38_anchor_audit.tex", "tab:balerma_r38_anchor_audit",
            "Balerma nominal source-balance audit. R38 has zero external "
            "flow and zero signed connector-flow sum; its hydraulic head "
            "remains within 0.5 ft of 117 m. "
            "Positive reservoir supply denotes injection; negative supply "
            "denotes absorption.",
            ["Design", r"$H_{38}$ (m)", r"$Q_{38}$ (L/s)",
             r"$\Sigma Q_{38}$ (L/s)",
             r"$Q_{43}$ (L/s)", r"$Q_{44}$ (L/s)",
             r"$Q_{88}$ (L/s)"], body)

service_cols = ["MeanWaterPct", "WorstWaterPct",
                "MeanChlorineCompliantPct", "WorstChlorineCompliantPct"]
maxima = {k: max(float(service[obj][k]) for obj in keys) for k in service_cols}
body = []
for key in keys:
    body.append([names[key]] + [best(service[key][k], maxima[k], places=2)
                                for k in service_cols])
write_table("balerma_r38_service.tex", "tab:balerma_r38_service",
            "Balerma demand-weighted service under 448 pressure-driven "
            "single-pipe failures per design, with all four reservoirs "
            "available and their six direct connectors protected. "
            "Chlorine-compliant service requires at least 0.2 mg/L at "
            "delivered-demand nodes. Bold italics mark the highest values.",
            ["Design", "Water mean (\\%)", "Water worst (\\%)",
             "Cl mean (\\%)", "Cl worst (\\%)"], body)

vulnerability = {}
for key in keys:
    selected = [r for r in cases if r["Objective"] == key]
    assert len(selected) == 448 and all(r["Nonconvergent"] == "0" for r in selected)
    water = [float(r["DeliveredDemandFraction"]) for r in selected]
    joint = [float(r["QualityCompliantDemandFraction"]) for r in selected]
    n10 = math.ceil(len(water) * 0.1)
    vulnerability[key] = [100 * (1 - sum(sorted(water)[:n10]) / n10),
                          100 * (1 - sum(sorted(joint)[:n10]) / n10),
                          100 * sum(w < 0.95 for w in water) / len(water),
                          100 * sum(w - c for w, c in zip(water, joint)) / len(water)]
mins = [min(vulnerability[key][j] for key in keys) for j in range(4)]
body = []
for key in keys:
    body.append([names[key]] + [best(vulnerability[key][j], mins[j],
                                    places=3 if j == 3 else 2)
                                for j in range(4)])
write_table("balerma_r38_vulnerability.tex", "tab:balerma_r38_vulnerability",
            "Balerma service vulnerability in the same 448 cases. The "
            "worst-10\\% deficit averages the 45 largest case deficits; "
            "below 95\\% is the share of cases with water service below 95\\%. "
            "Cl-only loss is the mean water-minus-chlorine-compliant "
            "service gap in percentage points. Bold italics mark minima before rounding.",
            ["Design", "Worst 10\\% water", "Worst 10\\% joint",
             "Below 95\\%", "Cl-only loss [pp]"], body)

topology = [r for r in read("topological_outage_audit/"
                             "topological_pipe_disconnection_ranking.csv")
            if r["ReservoirState"] == "all_four"]
assert len(topology) == 448
body = [["P" + r["FailedPipeID"], r["DisconnectedConsumers"],
         fmt(r["DisconnectedConsumersPctOfTotal"], 2),
         fmt(r["DisconnectedDemandLps"], 2),
         fmt(r["DisconnectedDemandPctOfTotal"], 2)]
        for r in topology[:10]]
write_table("balerma_r38_topology.tex", "tab:balerma_r38_topology",
            "Ten Balerma pipe failures with the largest topological "
            "disconnection under all-four-reservoir availability. "
            "The percentages use all 442 consumers or the original total "
            "demand as denominator; diameter changes cannot serve "
            "components with no reservoir path.",
            ["Pipe", "Consumers", "Consumers (\\%)", "Demand (L/s)",
             "Demand (\\%)"], body)

rank = read("pipe_rankings_top90.csv")
assert len(rank) == 90
rank_columns = ["flow_rate", "pressure_sensitivity", "nodal_entropy",
                "entropy_sensitivity", "volume"]
lines = [r"\begingroup", r"\footnotesize",
         r"\setlength{\tabcolsep}{3pt}",
         r"\begin{longtable}{rlllllr}",
         r"\caption{Balerma pipe IDs ordered by five frozen rankings "
         r"computed at the anchor-feasible reference design. The final "
         r"column marks the subset sizes used in the ranking figures. "
         r"Only the first 90 of 454 pipes are shown.}"
         r"\label{tab:balerma_r38_rankings}\\",
         r"\toprule",
         r"Rank & Flow & Pressure sens. & Nodal entropy & Entropy sens. & Volume & Released \\",
         r"\midrule", r"\endfirsthead",
         r"\multicolumn{7}{l}{Table \thetable\ continued}\\",
         r"\toprule",
         r"Rank & Flow & Pressure sens. & Nodal entropy & Entropy sens. & Volume & Released \\",
         r"\midrule", r"\endhead", r"\bottomrule", r"\endfoot"]
for r in rank:
    n = int(r["Rank"])
    pct = f"{100*n/454:.2f}\\%" if n in {5, 20, 45, 70, 90} else ""
    lines.append(" & ".join([str(n)] + ["P"+r[k] for k in rank_columns] +
                            [pct]) + r" \\")
lines.extend([r"\end{longtable}", r"\endgroup"])
(output_dir / "balerma_r38_rankings.tex").write_text("\n".join(lines)+"\n")

print(f"Wrote nine Balerma R38-anchor tables to {output_dir}")
