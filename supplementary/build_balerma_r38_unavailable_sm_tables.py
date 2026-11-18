#!/usr/bin/env python3
"""Write the two R38-unavailable Balerma SM tables from saved PDA cases.

Usage: python3 supplementary/build_balerma_r38_unavailable_sm_tables.py RESULT_DIR DRAFT_DIR
No hydraulic or water-quality calculation is performed here.
"""
from __future__ import annotations

import csv
import math
import pathlib
import sys

root = pathlib.Path(sys.argv[1]) / "r38_unavailable_protected"
out = pathlib.Path(sys.argv[2])
keys = ["cost", "hydraulic_entropy", "branch_hop_weighted_entropy",
        "chlorine_concentration", "chlorine_entropy", "todini"]
names = {"cost": "Cost", "hydraulic_entropy": "Flow entropy",
         "branch_hop_weighted_entropy": "Branch-hop entropy",
         "chlorine_concentration": "Cl concentration",
         "chlorine_entropy": "Cl entropy", "todini": "Todini"}


def load(name: str) -> list[dict[str, str]]:
    with (root / name).open(newline="") as handle:
        return list(csv.DictReader(handle))


def mark(value: float, optimum: float, *, places: int = 2) -> str:
    cell = f"{value:.{places}f}"
    if math.isclose(value, optimum, rel_tol=1e-10, abs_tol=1e-10):
        return r"\textbf{\textit{" + cell + "}}"
    return cell


def write(name: str, label: str, caption: str, columns: list[str],
          rows: list[list[str]], layout: str) -> None:
    lines = [r"\begin{table}[htbp]", r"\centering\footnotesize",
             r"\setlength{\tabcolsep}{3pt}", r"\caption{" + caption + "}",
             r"\label{" + label + "}", r"\begin{tabular}{" + layout + "}",
             r"\toprule", " & ".join(columns) + r" \\", r"\midrule"]
    lines += [" & ".join(row) + r" \\" for row in rows]
    lines += [r"\bottomrule", r"\end{tabular}", r"\end{table}"]
    (out / name).write_text("\n".join(lines) + "\n")


summary = load("summary.csv")
cases = load("cases.csv")
assert len(summary) == 6 and len(cases) == 6 * 448
assert [row["Objective"] for row in summary] == keys
for key in keys:
    selected = [r for r in cases if r["Objective"] == key]
    assert len(selected) == 448
    assert len({r["FailedLinkID"] for r in selected}) == 448
    assert all(r["Nonconvergent"] == "0" for r in selected)

greater = ["SourceOnlyWaterPct", "MeanWaterPct", "WorstWaterPct",
           "MeanChlorineCompliantPct", "WorstChlorineCompliantPct"]
maxima = {key: max(float(r[key]) for r in summary) for key in greater}
rows = []
for r in summary:
    rows.append([names[r["Objective"]]] +
                [mark(float(r[key]), maxima[key]) for key in greater] +
                ["P" + r["WorstWaterPipeID"]])
write("balerma_r38_unavailable_service.tex",
      "tab:balerma_r38_unavailable_service",
      "Balerma service with R38 unavailable and 448 pipe outages per design. "
      "R43, R44, and R88 remain connected; their four direct connectors "
      "are protected. Source only has no pipe outage. Service values are "
      "percentages; Cl compliance requires at least 0.2 mg/L.",
      ["Design", "Source only", "Water mean", "Water worst",
       "Cl mean", "Cl worst", "Worst pipe"], rows, "lrrrrrl")

stats: dict[str, list[float]] = {}
for key in keys:
    selected = [r for r in cases if r["Objective"] == key]
    water = [float(r["DeliveredDemandFraction"]) for r in selected]
    joint = [float(r["QualityCompliantDemandFraction"]) for r in selected]
    n10 = math.ceil(len(water) * 0.1)
    stats[key] = [100 * (1 - sum(sorted(water)[:n10]) / n10),
                  100 * (1 - sum(sorted(joint)[:n10]) / n10),
                  100 * sum(w < 0.95 for w in water) / len(water),
                  100 * sum(w - c for w, c in zip(water, joint)) / len(water)]
minima = [min(stats[key][j] for key in keys) for j in range(4)]
rows = [[names[key]] + [mark(stats[key][j], minima[j], places=3 if j == 3 else 2)
                           for j in range(4)] for key in keys]
write("balerma_r38_unavailable_vulnerability.tex",
      "tab:balerma_r38_unavailable_vulnerability",
      "R38-unavailable vulnerability. Worst 10\\% averages the 45 "
      "largest deficits; below 95\\% is the share of cases with water "
      "service below 95\\%. Cl-only loss is the mean delivery-minus-"
      "compliance gap in percentage points.",
      ["Design", "Worst 10\\% water", "Worst 10\\% joint",
       "Below 95\\%", "Cl-only loss [pp]"], rows, "lrrrr")
print("Wrote R38-unavailable Balerma tables to", out)
