"""Format saved STACI/EPANET comparison CSVs as supplementary LaTeX tables.

This script formats results only; all hydraulics, chlorine, and GA calculations
are done by the MATLAB/STACI and independent EPANET scripts documented in the
repository README. Run from any directory with Python 3's standard library.
"""
from __future__ import annotations

import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUMMARY = ROOT / 'supplementary/results/staci_single_objective_summary.csv'
VALIDATION = ROOT / 'supplementary/results/validation_staci_15/staci_epanet_15_designs.csv'
OUTPUT = ROOT / 'supplementary/results'
NETWORKS = {'tanyimboh_templeman': 'TT', 'anytown': 'AT', 'balerma': 'BA'}
OBJECTIVES = {
    'cost': 'Cost',
    'hydraulic_entropy': 'Hyd. entropy',
    'chlorine_concentration': 'Cl conc.',
    'chlorine_entropy': 'Cl entropy',
    'todini': 'Todini',
}


def rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline='', encoding='utf-8') as stream:
        return list(csv.DictReader(stream))


def number(value: str, digits: int = 3) -> str:
    x = float(value)
    if not math.isfinite(x):
        return '--'
    raw = f'{x:.{digits}g}'
    if 'e' in raw:
        mantissa, exponent = raw.split('e')
        return rf'${mantissa}\times10^{{{int(exponent)}}}$'
    return raw


def stop_reason(record: dict[str, str]) -> str:
    message = record['ga_stop_message'].lower().replace(' ', '')
    generation = int(float(record['ga_generations']))
    cap = int(float(record['ga_generation_cap']))
    if 'functiontolerance' in message:
        return 'function tol.'
    if 'stall' in message:
        return 'stall'
    if 'wall' in message or 'time' in message:
        return 'wall limit'
    if generation >= cap:
        return 'generation cap'
    return f"exit {record['ga_exitflag']}"


def ga_table(data: list[dict[str, str]]) -> str:
    assert len(data) == 15
    lines = [
        r'\begin{table}[H]', r'\centering\scriptsize',
        r'\caption{Actual stopping audit for the 15 final STACI single-objective searches. TT: Tanyimboh--Templeman; AT: Anytown; BA: Balerma. Fitness calls exclude separate final-result and EPANET replay solves. Wall time is a single-run measurement and can be affected by concurrent processes.}',
        r'\label{tab:ga-stops}',
        r'\begin{tabular}{llrrrl}', r'\toprule',
        r'Network & Objective & Gen./cap & Fitness calls & Wall (s) & MATLAB stop \\',
        r'\midrule',
    ]
    for record in data:
        network = NETWORKS[record['network']]
        objective = OBJECTIVES[record['objective']]
        generation = int(float(record['ga_generations']))
        cap = int(float(record['ga_generation_cap']))
        evaluations = int(float(record['ga_function_evaluations']))
        wall = number(record['ga_wall_seconds'], 4)
        lines.append(f'{network} & {objective} & {generation}/{cap} & {evaluations} & {wall} & {stop_reason(record)} ' + r'\\')
    lines += [r'\bottomrule', r'\end{tabular}', r'\end{table}']
    return '\n'.join(lines) + '\n'


def validation_table(data: list[dict[str, str]]) -> str:
    assert len(data) == 15
    columns = ['max_abs_head_m', 'mean_abs_head_m',
               'max_abs_flow_Lps', 'mean_abs_flow_Lps',
               'max_abs_chlorine_mgL', 'mean_abs_chlorine_mgL']
    lines = [
        r'\begin{table}[H]', r'\centering\scriptsize',
        r'\caption{Independent EPANET 2.2 replay of all 15 final STACI designs. Each entry is the maximum or arithmetic mean absolute STACI--EPANET difference across all corresponding nodes or links. $H$: total head (m); $Q$: signed link flow (L/s); $c$: stationary chlorine (mg/L).}',
        r'\label{tab:final-differences}', r'\resizebox{\textwidth}{!}{%',
        r'\begin{tabular}{llrrrrrr}', r'\toprule',
        r'Network & Objective & $H_{\max}$ & $H_{\rm mean}$ & $Q_{\max}$ & $Q_{\rm mean}$ & $c_{\max}$ & $c_{\rm mean}$ \\',
        r'\midrule',
    ]
    for record in data:
        network = NETWORKS[record['network']]
        objective = OBJECTIVES[record['objective']]
        values = ' & '.join(number(record[name], 3) for name in columns)
        lines.append(f'{network} & {objective} & {values} ' + r'\\')
    lines += [r'\bottomrule', r'\end{tabular}}', r'\end{table}']
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    OUTPUT.joinpath('staci_ga_stop_table.tex').write_text(
        ga_table(rows(SUMMARY)), encoding='utf-8')
    OUTPUT.joinpath('staci_epanet_validation_table.tex').write_text(
        validation_table(rows(VALIDATION)), encoding='utf-8')
    print('Wrote supplementary LaTeX tables from 15 saved STACI designs.')
