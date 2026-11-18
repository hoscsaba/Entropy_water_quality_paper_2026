#!/usr/bin/env python3
"""Render Balerma common-bound CSV audits as supplementary LaTeX tables."""
import csv
import math
import pathlib
import sys

result_dir = pathlib.Path(sys.argv[1])
output_dir = pathlib.Path(sys.argv[2])
validation_csv = pathlib.Path(sys.argv[3])
unavailable_reservoir = sys.argv[4] if len(sys.argv) > 4 else 'R43'
assert unavailable_reservoir in {'R38', 'R43', 'R44'}
output_dir.mkdir(parents=True, exist_ok=True)

OBJECTIVES = [
    ('Cost', 'Cost'),
    ('Flow entropy', 'Flow entropy'),
    ('Branch-hop entropy', 'Branch-hop entropy'),
    ('Cl concentration', 'Cl concentration'),
    ('Cl entropy', 'Cl entropy'),
    ('Todini', 'Todini'),
]
LABEL = {key: name for key, name in OBJECTIVES}
LABEL.update({
    'Hydraulic entropy': 'Flow entropy',
    'Branch-hop weighted entropy': 'Branch-hop entropy',
    'Chlorine concentration': 'Cl concentration',
    'Chlorine entropy': 'Cl entropy',
})
KEY_LABEL = {
    'cost': 'Cost',
    'hydraulic_entropy': 'Flow entropy',
    'branch_hop_weighted_entropy': 'Branch-hop entropy',
    'branch_hop_weighted_entropy_rank45': 'Branch-hop entropy',
    'chlorine_concentration': 'Cl concentration',
    'chlorine_entropy': 'Cl entropy',
    'todini': 'Todini',
}

def rows(path):
    with path.open(newline='') as stream:
        return list(csv.DictReader(stream))

def number(value, digits=3):
    x = float(value)
    return f'{x:,.{digits}f}' if math.isfinite(x) else '--'

def short(value):
    x = float(value)
    return f'{x:.3g}' if math.isfinite(x) else '--'

def tex(text):
    return str(text).replace('_', r'\_').replace('%', r'\%')

def save(filename, contents):
    (output_dir / filename).write_text(contents + '\n', encoding='utf-8')

def tabular(filename, label, caption, headings, body, *, font='\\footnotesize', widths=None):
    if widths is None:
        widths = 'l' + 'r' * (len(headings) - 1)
    lines = [r'\begin{table}[p]', r'\centering' + font,
             r'\setlength{\tabcolsep}{3pt}',
             r'\caption{' + caption + '}', r'\label{' + label + '}',
             r'\begin{tabular}{' + widths + '}', r'\toprule',
             ' & '.join(headings) + r' \\', r'\midrule']
    lines += [' & '.join(row) + r' \\' for row in body]
    lines += [r'\bottomrule', r'\end{tabular}', r'\end{table}']
    save(filename, '\n'.join(lines))

# The exact diameter vectors are linked as CSV in the Supplementary Material.
# Keep a row-count check, but do not generate a 454-row print table.
diameter_rows = rows(result_dir / 'optimal_pipe_diameters_six_in.csv')
assert len(diameter_rows) == 454

# The first 90 pipes of every frozen original-network ranking.
rank_rows = rows(result_dir / 'pipe_rankings_top90.csv')
assert len(rank_rows) == 90
released = {5, 20, 45, 70, 90}
rank_head = ['Rank', 'Flow rate', 'Pressure sens.', 'Nodal entropy',
             'Entropy sens.', 'Pipe volume', 'Released']
lines = [r'\begingroup', r'\footnotesize', r'\setlength{\tabcolsep}{3pt}',
         r'\begin{longtable}{rlllllr}',
         r'\caption{Balerma physical-pipe IDs in descending priority under five '
         r'original-network rankings. The first $K$ entries in a column form the '
         r'nested subset; only the top 90 of 454 pipes are listed. The final column '
         r'marks the subset sizes plotted in Figures~\ref{fig:balerma_common_ranked_cost_branch}--'
         r'\ref{fig:balerma_common_ranked_chlorine}.}'
         r'\label{tab:balerma_common_rankings}\\',
         r'\toprule', ' & '.join(rank_head) + r' \\', r'\midrule',
         r'\endfirsthead', r'\multicolumn{7}{l}{Table \thetable\ continued}\\',
         r'\toprule', ' & '.join(rank_head) + r' \\', r'\midrule', r'\endhead',
         r'\bottomrule', r'\endfoot']
for row in rank_rows:
    k = int(row['Rank'])
    pct = number(row['ReleasedPercent'], 2) + r'\%' if k in released else ''
    vals = [str(k), row['FlowRate'], row['PressureSensitivity'],
            row['NodalEntropy'], row['EntropySensitivity'], row['Volume'], pct]
    lines.append(' & '.join(vals) + r' \\')
lines += [r'\end{longtable}', r'\endgroup']
save('balerma_common_rankings.tex', '\n'.join(lines))

raw = rows(result_dir / 'cross_evaluation_six_raw.csv')
relative = rows(result_dir / 'cross_evaluation_six.csv')
assert len(raw) == len(relative) == 6
order = ['Cost', 'FlowEntropy', 'BranchHopEntropy',
         'ChlorineConcentration', 'ChlorineEntropy', 'Todini']
head = ['Design', r'Cost [$10^6$]', r'$S_Q$', r'$S_b$',
        r'$J_{\mathrm{Cl}}$', r'$S_{\mathrm{Cl}}$', 'Todini']
raw_body = []
for row in raw:
    vals = [number(float(row[key]) / 1e6) if key == 'Cost'
            else number(row[key]) for key in order]
    raw_body.append([LABEL[row['OptimizedFor']]] + vals)
tabular('balerma_common_raw.tex', 'tab:balerma_common_raw',
        'Balerma nominal objectives for six full-network common-bound designs. '
        r'Cost is in $10^6$ relative units; $S_Q$, $S_b$, and $S_{\mathrm{Cl}}$ '
        r'are in nat; $J_{\mathrm{Cl}}$ is in $(\mathrm{mg/L})^2$.',
        head, raw_body)

relative_body = []
for row in relative:
    vals = []
    for key in order:
        cell = number(row[key])
        if abs(float(row[key]) - 1) < 1e-9:
            cell = r'\textbf{\textit{' + cell + '}}'
        vals.append(cell)
    relative_body.append([LABEL[row['OptimizedFor']]] + vals)
tabular('balerma_common_relative.tex', 'tab:balerma_common_relative',
        'Balerma nominal objectives for the same six designs, normalized to '
        'the lowest saved cost or highest saved score. Bold italics indicate '
        'the best value in each column.',
        ['Design', 'Cost', r'$S_Q$', r'$S_b$', r'$J_{\mathrm{Cl}}$',
         r'$S_{\mathrm{Cl}}$', 'Todini'], relative_body)

# Fresh GA records are kept distinct from post-search incumbent selection.
ga_rows = rows(result_dir / 'ga_stop_six_full.csv')
selected = {r['Objective']: r for r in rows(result_dir / 'elite_adjudication.csv')}
assert len(ga_rows) == 6 and len(selected) == 6
ga_body = []
for row in ga_rows:
    objective = row['Objective']
    source = selected[objective]['SelectedSource'].replace('common GA:', 'fresh GA:')
    ga_body.append([KEY_LABEL[objective], number(row['Generations'], 0),
                    number(row['Evaluations'], 0), number(row['WallSeconds'], 1),
                    tex(source)])
tabular('balerma_common_ga.tex', 'tab:balerma_common_ga',
        'Balerma fresh full-network genetic searches and feasible-incumbent '
        'selection. Generations, evaluations, and elapsed time belong to the '
        'fresh GA; the final column identifies the selected vector after all '
        'new and earlier vectors were rechecked under the common constraints.',
        ['Objective', 'Gen.', 'Eval.', 'GA time (s)', 'Selected vector'],
        ga_body, widths='lrrrl')

validation = rows(validation_csv)
assert len(validation) == 6
v_body = []
for row in validation:
    v_body.append([KEY_LABEL[row['objective']]] +
                  [short(row[key]) for key in
                   ['max_abs_head_m', 'mean_abs_head_m',
                    'max_abs_flow_Lps', 'mean_abs_flow_Lps',
                    'max_abs_chlorine_mgL', 'mean_abs_chlorine_mgL']])
tabular('balerma_common_epanet.tex', 'tab:balerma_common_epanet',
        'Balerma independent STACI--EPANET 2.2 differences for the six '
        'common-bound nominal designs: maximum and mean absolute differences '
        'in nodal total head (m), signed pipe flow (L/s), and stationary '
        'chlorine residual (mg/L), matched by ID.',
        ['Design', r'$\Delta H_{\max}$', r'$\overline{|\Delta H|}$',
         r'$\Delta Q_{\max}$', r'$\overline{|\Delta Q|}$',
         r'$\Delta c_{\max}$', r'$\overline{|\Delta c|}$'], v_body)

service = rows(result_dir / 'pda_service_six.csv')
vulnerability = rows(result_dir / 'pda_vulnerability_summary.csv')
assert len(service) == len(vulnerability) == 6
service_columns = ['MeanDeliveredDemandFraction', 'WorstDeliveredDemandFraction',
                   'MeanQualityCompliantDemandFraction',
                   'WorstQualityCompliantDemandFraction']
maxima = [max(float(r[k]) for r in service) for k in service_columns]
s_body = []
for row in service:
    vals = []
    for key, mx in zip(service_columns, maxima):
        value = 100 * float(row[key])
        cell = number(value, 2)
        if abs(value - 100 * mx) < 1e-8:
            cell = r'\textbf{\textit{' + cell + '}}'
        vals.append(cell)
    s_body.append([KEY_LABEL[row['Objective']]] + vals)
tabular('balerma_common_service.tex', 'tab:balerma_common_service',
        'Balerma mean and minimum demand-weighted service across 908 '
        'pressure-driven pipe-outage cases per design: 454 with all four '
        f'reservoirs and 454 with {unavailable_reservoir} unavailable. '
        'Chlorine-compliant service '
        'requires at least 0.2~mg/L at delivered-demand nodes. Bold italics '
        'mark the highest values.',
        ['Design', r'Water mean (\%)', r'Water worst (\%)',
         r'Cl mean (\%)', r'Cl worst (\%)'], s_body)

v_columns = ['WorstTenPercentWaterDeficitPct',
             'WorstTenPercentJointDeficitPct', 'Below95WaterPct',
             'MeanChlorineOnlyLossPct']
minima = [min(float(r[k]) for r in vulnerability) for k in v_columns]
v_body = []
for row in vulnerability:
    vals = []
    for key, mn in zip(v_columns, minima):
        value = float(row[key]); cell = number(value, 3 if key == v_columns[-1] else 2)
        if abs(value - mn) < 1e-8:
            cell = r'\textbf{\textit{' + cell + '}}'
        vals.append(cell)
    v_body.append([KEY_LABEL[row['Objective']]] + vals)
tabular('balerma_common_vulnerability.tex', 'tab:balerma_common_vulnerability',
        'Balerma conditional vulnerability across the same 908 cases. '
        r'Worst 10\% averages the 91 largest deficits; below 95\% is the '
        r'share of cases with less than 95\% water delivery. Cl-only loss is '
        'the mean gap between water and chlorine-compliant service, in '
        'percentage points. Bold italics mark the lowest values.',
        ['Design', r'Worst 10\% water', r'Worst 10\% joint',
         r'Below 95\%', 'Cl-only loss [pp]'], v_body)

print(f'Wrote eight common-bound Balerma TeX tables to {output_dir}')
