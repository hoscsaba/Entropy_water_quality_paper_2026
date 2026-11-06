"""Render the current Supplementary GA and STACI--EPANET audit tables.

Only released CSVs are read. This script performs no optimization or hydraulic
simulation; those are done by the MATLAB/STACI and EPANET procedures in README.
"""
from __future__ import annotations

import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'supplementary' / 'results'
TT = ROOT / 'networks' / 'tanyimboh_templeman' / 'results_staci'
AT = ROOT / 'networks' / 'anytown' / 'results_staci_anchor_replay'
BA = ROOT / 'networks' / 'balerma' / 'results_staci'
LABELS = {
    'cost': 'Cost',
    'hydraulic_entropy': 'Hyd. entropy',
    'branch_hop_weighted_entropy': 'Branch-hop',
    'chlorine_concentration': 'Cl conc.',
    'chlorine_entropy': 'Cl entropy',
    'todini': 'Todini',
    'branch_hop_weighted_entropy_rank45': 'Branch-hop (45 pipes)',
}
ORDER = ('cost', 'hydraulic_entropy', 'branch_hop_weighted_entropy',
         'chlorine_concentration', 'chlorine_entropy', 'todini')
NETWORKS = ('tanyimboh_templeman', 'anytown', 'balerma')
ABBREV = {'tanyimboh_templeman': 'TT', 'anytown': 'AT', 'balerma': 'BA'}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline='', encoding='utf-8') as stream:
        return list(csv.DictReader(stream))


def number(value: str | float, digits: int = 3) -> str:
    x = float(value)
    if not math.isfinite(x):
        return '--'
    raw = f'{x:.{digits}g}'
    if 'e' in raw:
        mantissa, exponent = raw.split('e')
        return rf'${mantissa}\times10^{{{int(exponent)}}}$'
    return raw


def order_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    rank = {name: i for i, name in enumerate(ORDER)}
    return sorted(rows, key=lambda row: (NETWORKS.index(row['network']),
        rank.get(row['objective'], len(rank))))


def ga_records() -> list[dict[str, str | int | float]]:
    records: list[dict[str, str | int | float]] = []
    tt_common = [r for r in read_csv(TT / 'ga_stop_common.csv')
                 if r['network'] == 'tanyimboh_templeman']
    assert len(tt_common) == 5
    for row in tt_common:
        records.append(dict(network='tanyimboh_templeman', objective=row['objective'],
            generations=row['ga_generations'], cap=row['ga_generation_cap'],
            evaluations=row['ga_function_evaluations'], wall=row['ga_wall_seconds'],
            stop='function tol.'))
    branch = read_csv(TT / 'branch_hop_ga_stop.csv')
    assert len(branch) == 1 and 'FunctionTolerance' in branch[0]['StopMessage']
    row = branch[0]
    records.append(dict(network='tanyimboh_templeman',
        objective='branch_hop_weighted_entropy', generations=row['Generations'],
        cap=10000, evaluations=row['Evaluations'], wall=row['WallSeconds'],
        stop='function tol.'))
    label_map = {'Cost': 'cost', 'Flow entropy': 'hydraulic_entropy',
        'Branch-hop entropy': 'branch_hop_weighted_entropy',
        'Cl concentration': 'chlorine_concentration',
        'Cl entropy': 'chlorine_entropy', 'Todini': 'todini',
        'Hydraulic entropy': 'hydraulic_entropy',
        'Chlorine concentration': 'chlorine_concentration',
        'Chlorine entropy': 'chlorine_entropy'}
    for network, path, key in (
        ('anytown', AT / 'ga_stop_six.csv', 'OptimizedFor'),
        ('balerma', BA / 'ga_stop_six.csv', 'Objective')):
        source = read_csv(path)
        if network == 'balerma':
            source = [row for row in source if row['SearchScope'] == '454 pipes']
        for row in source:
            records.append(dict(network=network, objective=label_map[row[key]],
                generations=row['Generations'], cap=10000,
                evaluations=row['Evaluations'], wall=row['WallSeconds'],
                stop='function tol.'))
    assert len(records) == 17
    return order_rows(records)


def render_ga(records: list[dict[str, str | int | float]]) -> str:
    lines = [r'\begin{table}[H]', r'\centering\scriptsize',
        r'\caption{Actual final-stage stopping audit for 17 full-network STACI single-objective designs. TT: Tanyimboh--Templeman; AT: Anytown; BA: Balerma. The restricted Balerma branch-hop search follows a different 45-pipe protocol and is excluded. Fitness calls exclude final-result and EPANET replays; wall time depends on hardware and concurrent processes.}',
        r'\label{tab:ga-stops}', r'\begin{tabular}{llrrrl}', r'\toprule',
        r'Network & Objective & Gen./cap & Fitness calls & Wall (s) & MATLAB stop \\',
        r'\midrule']
    for row in records:
        name = ABBREV[str(row['network'])]
        objective = LABELS[str(row['objective'])]
        generations = int(float(row['generations']))
        cap = int(float(row['cap']))
        evaluations = int(float(row['evaluations']))
        lines.append(f'{name} & {objective} & {generations}/{cap} & '
                     f'{evaluations} & {number(row["wall"], 4)} & '
                     f'{row["stop"]} ' + r'\\')
    lines += [r'\bottomrule', r'\end{tabular}', r'\end{table}']
    return '\n'.join(lines) + '\n'


def validation_records() -> list[dict[str, str]]:
    sources = (OUT / 'validation_staci_tanyimboh' / 'staci_epanet_tanyimboh_six.csv',
        OUT / 'validation_anytown_anchor_replay' / 'staci_epanet_anytown_anchor_replay_six.csv',
        OUT / 'validation_staci_balerma_connected' / 'staci_epanet_balerma_connected_six.csv')
    data = [row for source in sources for row in read_csv(source)]
    assert len(data) == 18
    assert len({(row['network'], row['objective']) for row in data}) == 18
    return order_rows(data)


def render_validation(data: list[dict[str, str]]) -> str:
    columns = ('max_abs_head_m', 'mean_abs_head_m',
        'max_abs_flow_Lps', 'mean_abs_flow_Lps',
        'max_abs_chlorine_mgL', 'mean_abs_chlorine_mgL')
    lines = [r'\begin{table}[H]', r'\centering\scriptsize',
        r'\caption{Independent EPANET 2.2 replay of 17 full-network final STACI designs and one restricted 45-pipe Balerma design. Each entry is the maximum or arithmetic mean absolute STACI--EPANET difference across corresponding nodes or links. $H$: total head (m); $Q$: signed link flow (L/s); $c$: stationary chlorine (mg/L).}',
        r'\label{tab:final-differences}', r'\resizebox{\textwidth}{!}{%',
        r'\begin{tabular}{llrrrrrr}', r'\toprule',
        r'Network & Objective & $H_{\max}$ & $H_{\rm mean}$ & $Q_{\max}$ & $Q_{\rm mean}$ & $c_{\max}$ & $c_{\rm mean}$ \\',
        r'\midrule']
    for row in data:
        values = ' & '.join(number(row[column]) for column in columns)
        lines.append(f'{ABBREV[row["network"]]} & {LABELS[row["objective"]]} & '
                     f'{values} ' + r'\\')
    lines += [r'\bottomrule', r'\end{tabular}}', r'\end{table}']
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    (OUT / 'staci_ga_stop_table.tex').write_text(render_ga(ga_records()), encoding='utf-8')
    (OUT / 'staci_epanet_validation_table.tex').write_text(
        render_validation(validation_records()), encoding='utf-8')
    print('Wrote stopping and EPANET tables for 17 full-network plus one restricted design.')
