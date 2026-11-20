#!/usr/bin/env python3
"""Compare STACI steady chlorine with EPANET EPS on current fixed-load designs.

Requires the STACI executable and EPANET 2.2 shared library. Inputs are
generated from the common fixed-load INPs and final STACI MAT designs.
The only Python dependency is NumPy (for reading MATLAB v5 MAT files).
"""

import argparse
import csv
import ctypes as ct
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from read_paper_mat import read as read_design

NETWORKS = ("tanyimboh_templeman", "anytown", "balerma")
DESIGNS = ("cost", "hydraulic_entropy", "branch_hop_weighted_entropy",
           "chlorine_concentration", "chlorine_entropy", "todini")
CASES = {
    "tanyimboh_templeman": ("network_staci_fixed_load.inp",
                            "results_staci_10_120_clsplit_v2", {"1", "2"},
                            ("4", "6", "5")),
    "anytown": ("network_anchor_replay.inp", "results_staci_anchor_replay",
                {"10"}, ("20", "100", "170", "140", "80", "90")),
    "balerma": ("network_r38_anchor_fixed_load.inp",
                "results_staci_r38_anchor_r44_physical_0p1_64in_v1",
                {"43", "44", "88"},
                ("179001", "246", "422", "337", "72", "336")),
}


class Epanet:
    def __init__(self, library):
        self.lib = ct.CDLL(str(library))
        definitions = {
            "ENopen": (ct.c_char_p, ct.c_char_p, ct.c_char_p),
            "ENclose": (), "ENgetcount": (ct.c_int, ct.POINTER(ct.c_int)),
            "ENgetnodeid": (ct.c_int, ct.c_char_p),
            "ENgetlinkindex": (ct.c_char_p, ct.POINTER(ct.c_int)),
            "ENgetnodevalue": (ct.c_int, ct.c_int, ct.POINTER(ct.c_float)),
            "ENsetnodevalue": (ct.c_int, ct.c_int, ct.c_float),
            "ENsetlinkvalue": (ct.c_int, ct.c_int, ct.c_float),
            "ENsetqualtype": (ct.c_int, ct.c_char_p, ct.c_char_p, ct.c_char_p),
            "ENsettimeparam": (ct.c_int, ct.c_long),
            "ENsaveinpfile": (ct.c_char_p,),
            "ENopenH": (), "ENinitH": (ct.c_int,),
            "ENrunH": (ct.POINTER(ct.c_long),),
            "ENnextH": (ct.POINTER(ct.c_long),), "ENcloseH": (),
            "ENopenQ": (), "ENinitQ": (ct.c_int,),
            "ENrunQ": (ct.POINTER(ct.c_long),),
            "ENnextQ": (ct.POINTER(ct.c_long),), "ENcloseQ": (),
            "ENgeterror": (ct.c_int, ct.c_char_p, ct.c_int),
        }
        for name, types in definitions.items():
            fn = getattr(self.lib, name)
            fn.restype = ct.c_int
            fn.argtypes = types

    def call(self, name, *args):
        code = getattr(self.lib, name)(*args)
        if code >= 200:
            msg = ct.create_string_buffer(512)
            self.lib.ENgeterror(code, msg, len(msg))
            raise RuntimeError(f"{name}: {code}: {msg.value.decode()}")

    def node_ids(self):
        count = ct.c_int()
        self.call("ENgetcount", 0, ct.byref(count))
        ids = []
        for index in range(1, count.value + 1):
            name = ct.create_string_buffer(256)
            self.call("ENgetnodeid", index, name)
            ids.append(name.value.decode())
        return ids

    def value(self, index, property_code):
        value = ct.c_float()
        self.call("ENgetnodevalue", index, property_code, ct.byref(value))
        return value.value


def static_input(source, target, network):
    text = source.read_text()
    if network == "anytown":
        # Keep the Anytown pattern at the fixed-load 0.7 multiplier.
        match = re.search(r"(?ms)^\[PATTERNS\]\s*\n(.*?)(?=^\[)", text)
        if match is None:
            raise RuntimeError("Anytown [PATTERNS] section missing")
        replacement = []
        for line in match.group(1).splitlines():
            if line.strip().startswith("1 "):
                fields = line.split()
                line = " 1 " + " ".join("0.7" for _ in fields[1:])
            replacement.append(line)
        text = text[:match.start(1)] + "\n".join(replacement) + "\n" + text[match.end(1):]
    target.write_text(text)


def design_ids(network, source):
    if network == "anytown":
        return [str(i) for i in range(2, 78, 2)]
    if network == "tanyimboh_templeman":
        return ["P1", "P4", "P7", "P6", "P2", "P3", "P8", "P5"]
    section = re.search(r"(?ms)^\[PIPES\]\s*\n(.*?)(?=^\[)", source.read_text()).group(1)
    return [line.split()[0] for line in section.splitlines()
            if line.strip() and not line.lstrip().startswith(";")]


def write_case(epanet, network, design, out, max_days):
    input_name, result_dir, sources, _ = CASES[network]
    source = ROOT / "networks" / network / "input" / input_name
    raw = out / "base_fixed_load.inp"
    if network == "anytown":
        static_input(source, raw, network)
    else:
        shutil.copyfile(source, raw)
    epanet.call("ENopen", str(raw).encode(), str(out / "setup.rpt").encode(),
                str(out / "setup.bin").encode())
    try:
        diameters = read_design(ROOT / "networks" / network /
                                result_dir / f"{design}.mat").ravel()
        ids = design_ids(network, source)
        if len(ids) != len(diameters):
            raise RuntimeError(f"{network}/{design}: diameter count mismatch")
        for link_id, diameter in zip(ids, diameters):
            index = ct.c_int()
            epanet.call("ENgetlinkindex", link_id.encode(), ct.byref(index))
            epanet.call("ENsetlinkvalue", index.value, 0, ct.c_float(float(diameter)))
        epanet.call("ENsetqualtype", 1, b"Chlorine", b"mg/L", b"")
        ids = epanet.node_ids()
        for index, node_id in enumerate(ids, 1):
            epanet.call("ENsetnodevalue", index, 4, ct.c_float(1.0 if node_id in sources else 0.0))
            if node_id in sources:
                epanet.call("ENsetnodevalue", index, 7, ct.c_float(0.0))
                epanet.call("ENsetnodevalue", index, 5, ct.c_float(1.0))
        count = ct.c_int()
        epanet.call("ENgetcount", 2, ct.byref(count))
        for index in range(1, count.value + 1):
            epanet.call("ENsetlinkvalue", index, 6, ct.c_float(-1.0))
        epanet.call("ENsettimeparam", 2, 300)  # 5-min transport step
        epanet.call("ENsettimeparam", 5, 3600) # hourly reporting
        epanet.call("ENsettimeparam", 0, max_days * 86400)
        case = out / "fixed_load.inp"
        epanet.call("ENsaveinpfile", str(case).encode())
    finally:
        epanet.call("ENclose")
    text = case.read_text()
    text, count = re.subn(r"(?im)^(\s*TOLERANCE\s+)[-+0-9.eE]+",
                          r"\g<1>0.000001", text, count=1)
    if count != 1:
        raise RuntimeError("Saved INP lacks EPANET quality tolerance")
    case.write_text(text)
    return case



def epanet_trajectory(epanet, case, out, max_days, nodes,
                      trajectory_filename="trajectory.csv"):
    epanet.call("ENopen", str(case).encode(), str(out / "eps.rpt").encode(),
                str(out / "eps.bin").encode())
    try:
        epanet.call("ENsettimeparam", 0, max_days * 86400)
        all_ids = epanet.node_ids()
        node_index = {node_id: index for index, node_id in enumerate(all_ids, 1)}
        started = time.perf_counter()
        epanet.call("ENopenH")
        try:
            epanet.call("ENinitH", 1)
            while True:
                instant = ct.c_long()
                epanet.call("ENrunH", ct.byref(instant))
                step = ct.c_long()
                epanet.call("ENnextH", ct.byref(step))
                if step.value == 0:
                    break
        finally:
            epanet.call("ENcloseH")
        epanet.call("ENopenQ")
        try:
            epanet.call("ENinitQ", 0)
            trajectory = []
            daily = {}
            hourly_all = []
            while True:
                instant = ct.c_long()
                epanet.call("ENrunQ", ct.byref(instant))
                if instant.value % 3600 == 0:
                    row = {"hours": instant.value / 3600}
                    row.update({name: epanet.value(node_index[name], 12) for name in nodes})
                    trajectory.append(row)
                    all_values = {
                        name: epanet.value(index, 12)
                        for name, index in node_index.items()}
                    hourly_all.append((instant.value / 3600, all_values))
                    if instant.value % 86400 == 0:
                        daily[instant.value] = all_values
                step = ct.c_long()
                epanet.call("ENnextQ", ct.byref(step))
                if step.value == 0:
                    break
        finally:
            epanet.call("ENcloseQ")
        elapsed = time.perf_counter() - started
        with (out / trajectory_filename).open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=["hours", *nodes])
            writer.writeheader()
            writer.writerows(trajectory)
        last = max(daily)
        previous = daily.get(last - 86400)
        daily_change = (max(abs(daily[last][name] - previous[name])
                            for name in all_ids) if previous else math.nan)
        # A temporary plateau before a very slow path breaks through is not
        # convergence. Require every *later* hourly state to stay within
        # 1e-4 mg/L, with at least 24 h of observed stable tail.
        minimum = dict(hourly_all[-1][1])
        maximum = dict(hourly_all[-1][1])
        convergence_h = None
        for hour, state in reversed(hourly_all):
            for name in all_ids:
                minimum[name] = min(minimum[name], state[name])
                maximum[name] = max(maximum[name], state[name])
            variation = max(maximum[name] - minimum[name] for name in all_ids)
            if variation > 1.0e-4:
                break
            if hourly_all[-1][0] - hour >= 24:
                convergence_h = hour
        return trajectory, elapsed, daily[last], daily_change, convergence_h
    finally:
        epanet.call("ENclose")


def staci_steady(binary, case, out):
    prefix = out / "staci"
    started = time.perf_counter()
    run = subprocess.run([str(binary), "-q", str(case), "-o", str(prefix),
                          "--quality-mode", "chemical"], cwd=out,
                         capture_output=True, text=True)
    elapsed = time.perf_counter() - started
    if run.returncode:
        raise RuntimeError(run.stderr[-3000:] + run.stdout[-3000:])
    with (out / "staci-steady-nodes.csv").open(newline="") as stream:
        values = {row["node_id"]: float(row["chemical_concentration_kgm3"]) * 1000
                  for row in csv.DictReader(stream)}
    return values, elapsed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--staci", type=Path, required=True)
    parser.add_argument("--epanet", type=Path, default=ROOT / "third_party/epanet22_arm64/libepanet2.dylib")
    parser.add_argument("--output", type=Path,
                        default=ROOT / "supplementary/results/current_chlorine")
    parser.add_argument("--max-days", type=int, default=14)
    parser.add_argument("--designs", nargs="*", default=list(DESIGNS))
    parser.add_argument("--networks", nargs="*", choices=NETWORKS,
                        default=list(NETWORKS))
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    epanet = Epanet(args.epanet)
    summaries = []
    for network in args.networks:
        input_name, _, _, figure_nodes = CASES[network]
        sample = list(figure_nodes[:3])
        for design in args.designs:
            out = args.output / network / design
            out.mkdir(parents=True, exist_ok=True)
            previous_cwd = Path.cwd()
            try:
                # EPANET writes its hydraulics sidecar in the process CWD.
                os.chdir(out)
                case = write_case(epanet, network, design, out, args.max_days)
                steady, staci_cli_s = staci_steady(args.staci, case, out)
                trajectory, epanet_s, final_all, daily_change, convergence_h = epanet_trajectory(
                    epanet, case, out, args.max_days, figure_nodes)
            finally:
                os.chdir(previous_cwd)
            final = trajectory[-1]
            all_discrepancy = max(abs(final_all[node] - steady[node])
                                  for node in final_all)
            summary = {"network": network, "design": design,
                       "representative_nodes": ",".join(sample),
                       "duration_h": final["hours"],
                       "convergence_h": convergence_h,
                       "max_all_node_abs_difference_mgL": all_discrepancy,
                       "last_day_all_node_change_mgL": daily_change,
                       "epanet_eps_s": epanet_s, "staci_cli_s": staci_cli_s}
            summaries.append(summary)
            (out / "steady.json").write_text(json.dumps(steady, indent=2))
            (out / "epanet_final.json").write_text(json.dumps(final_all, indent=2))
            print(summary, flush=True)
    with (args.output / "summary.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(summaries[0]))
        writer.writeheader()
        writer.writerows(summaries)


if __name__ == "__main__":
    main()
