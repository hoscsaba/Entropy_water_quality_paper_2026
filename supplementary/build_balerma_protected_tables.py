"""Write Supplementary tables for Balerma with source connectors protected.

The input CSVs come from ``summarize_balerma_protected_connector_stress``.
No hydraulic, chlorine, or optimization calculation is performed here.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


LABELS = {
    "cost": "Cost",
    "hydraulic_entropy": "Flow entropy",
    "branch_hop_weighted_entropy": "Branch-hop entropy",
    "chlorine_concentration": "Cl concentration",
    "chlorine_entropy": "Cl entropy",
    "todini": "Todini",
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as stream:
        return list(csv.DictReader(stream))


def emphasize(value: float, best: float, decimals: int = 2) -> str:
    text = f"{value:.{decimals}f}"
    if abs(value - best) < 1e-8:
        return r"\textbf{\textit{" + text + "}}"
    return text


def write_table(
    path: Path, label: str, caption: str, headings: list[str],
    body: list[list[str]],
) -> None:
    columns = "l" + "r" * (len(headings) - 1)
    lines = [
        r"\begin{table}[p]",
        r"\centering\footnotesize",
        r"\setlength{\tabcolsep}{3pt}",
        r"\caption{" + caption + "}",
        r"\label{" + label + "}",
        r"\begin{tabular}{" + columns + "}",
        r"\toprule",
        " & ".join(headings) + r" \\",
        r"\midrule",
    ]
    lines.extend(" & ".join(row) + r" \\" for row in body)
    lines.extend([r"\bottomrule", r"\end{tabular}", r"\end{table}", ""])
    path.write_text("\n".join(lines))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("result_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    src = args.result_dir / "protected_connector_stress"
    out = args.output_dir
    out.mkdir(parents=True, exist_ok=True)
    service = read_csv(src / "pda_service_six.csv")
    vulnerability = read_csv(src / "pda_vulnerability_summary.csv")
    cases = read_csv(src / "pda_service_scenarios.csv")
    unfiltered_cases = read_csv(args.result_dir / "pda_service_scenarios.csv")
    assert len(service) == len(vulnerability) == 6 and len(cases) == 5376
    assert all(int(row["FailureCases"]) == 896 for row in service)

    cols = [
        "MeanDeliveredDemandFraction", "WorstDeliveredDemandFraction",
        "MeanQualityCompliantDemandFraction",
        "WorstQualityCompliantDemandFraction",
    ]
    maxima = {key: max(100 * float(row[key]) for row in service) for key in cols}
    body = [
        [LABELS[row["Objective"]]]
        + [emphasize(100 * float(row[key]), maxima[key]) for key in cols]
        for row in service
    ]
    write_table(
        out / "balerma_protected_service.tex",
        "tab:balerma_protected_service",
        "Balerma demand-weighted service over 896 pressure-driven cases per "
        "design: 448 eligible pipe failures with all four reservoirs and "
        "448 with R44 unavailable. Direct reservoir connectors are excluded "
        "from the failure candidates. Bold italics mark the highest values.",
        ["Design", r"Water mean (\%)", r"Water worst (\%)",
         r"Cl mean (\%)", r"Cl worst (\%)"],
        body,
    )

    vcols = [
        "WorstTenPercentWaterDeficitPct", "WorstTenPercentJointDeficitPct",
        "Below95WaterPct", "MeanChlorineOnlyLossPct",
    ]
    minima = {key: min(float(row[key]) for row in vulnerability) for key in vcols}
    body = [
        [LABELS[row["Objective"]]]
        + [
            emphasize(float(row[key]), minima[key], 3 if key == vcols[-1] else 2)
            for key in vcols
        ]
        for row in vulnerability
    ]
    write_table(
        out / "balerma_protected_vulnerability.tex",
        "tab:balerma_protected_vulnerability",
        "Balerma conditional vulnerability for the same 896 protected-connector "
        r"cases. Worst 10\% averages the 90 largest deficits. Below 95\% "
        "is the fraction of cases with less than 95\\% water delivery; "
        "Cl-only loss is the mean water-minus-chlorine-compliant service "
        "gap in percentage points. Bold italics mark the lowest values.",
        ["Design", r"Worst 10\% water", r"Worst 10\% joint",
         r"Below 95\%", "Cl-only loss [pp]"],
        body,
    )

    by_key = {(row["Objective"], row["ReservoirAvailability"]): []
              for row in cases}
    for row in cases:
        by_key[(row["Objective"], row["ReservoirAvailability"])].append(row)
    assert len(by_key) == 12 and all(len(group) == 448 for group in by_key.values())
    rows = []
    for design in service:
        name = design["Objective"]
        baseline_rows = [
            row for row in unfiltered_cases
            if row["Objective"] == name
            and row["ReservoirAvailability"] == "R44_unavailable"
            and row["FailedLinkID"] == "188"
        ]
        assert len(baseline_rows) == 1
        all_four_worst = 100 * min(
            float(row["DeliveredDemandFraction"])
            for row in by_key[(name, "all_four")]
        )
        r44_baseline = 100 * float(
            baseline_rows[0]["DeliveredDemandFraction"]
        )
        r44_worst = 100 * min(
            float(row["DeliveredDemandFraction"])
            for row in by_key[(name, "R44_unavailable")]
        )
        assert r44_baseline >= r44_worst - 1e-8
        values = [all_four_worst, r44_baseline, r44_worst,
                  r44_baseline - r44_worst]
        rows.append((name, values))
    best = [max(values[k] for _, values in rows) for k in range(3)]
    body = [[LABELS[name]] + [
                emphasize(value, best[k]) if k < 3 else f"{value:.2f}"
                for k, value in enumerate(values)]
            for name, values in rows]
    write_table(
        out / "balerma_protected_states.tex",
        "tab:balerma_protected_states",
        "Balerma water service by source availability with direct reservoir "
        "connectors protected. R44 alone denotes no additional pipe failure; "
        "it is the archived P188 no-op case with R44 unavailable. The worst "
        "columns enumerate 448 eligible failures per source state. "
        "Additional pipe loss is the R44-alone service minus the R44-plus-"
        "pipe minimum, in percentage points. Bold italics mark the highest "
        "service values.",
        ["Design", r"All four worst (\%)", r"R44 alone (\%)",
         r"R44 + pipe worst (\%)", "Additional loss [pp]"],
        body,
    )
    with (src / "r44_baseline_incremental_loss.csv").open("w", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["Objective", "AllFourWorstPct", "R44AlonePct",
                         "R44PlusPipeWorstPct", "AdditionalPipeLossPp"])
        for name, values in rows:
            writer.writerow([name, *values])
    print(f"Wrote three protected-connector tables to {out}")


if __name__ == "__main__":
    main()
