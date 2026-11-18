#!/usr/bin/env python3
"""Export extra Figure S1 chlorine histories from the saved original INPs.

The two additional panels use distant nodes with slower EPANET chlorine
buildup than those in the original overview panels. Anytown nodes 75 and
115 have zero demand; they show transport delay, not consumer service.
This script replays only the two fixed-load EPANET inputs already used in
the stationary-quality benchmark. It does not optimize pipe diameters.

Run from the repository root with::

    python3 supplementary/export_distal_chlorine_trajectories.py
"""

import json
import os
from pathlib import Path
import tempfile

from compare_steady_chlorine import Epanet, epanet_trajectory, ROOT


EXTRA_NODES = {
    "anytown": ("75", "115", "140"),
    "balerma": ("58", "213", "235"),
}


def main():
    epanet = Epanet(ROOT / "third_party/epanet22_arm64/libepanet2.dylib")
    for network, nodes in EXTRA_NODES.items():
        saved = ROOT / "supplementary/results" / network / "original"
        case = saved / "fixed_load.inp"
        steady = json.loads((saved / "steady.json").read_text())
        # EPANET creates a scratch hydraulics file in the working directory;
        # keep all transient files in a temporary folder.
        with tempfile.TemporaryDirectory(prefix=f"s1_{network}_") as scratch:
            scratch = Path(scratch)
            previous_dir = Path.cwd()
            try:
                os.chdir(scratch)
                _, _, final, _, _ = epanet_trajectory(
                    epanet, case, scratch, 14, list(nodes),
                    trajectory_filename="trajectory_distal.csv")
            finally:
                os.chdir(previous_dir)
            error = max(abs(final[node] - steady[node]) for node in nodes)
            if error > 0.001:
                raise RuntimeError(
                    f"{network}: EPANET/STACI final discrepancy {error:.6g} mg/L")
            destination = saved / "trajectory_distal.csv"
            destination.write_bytes((scratch / "trajectory_distal.csv").read_bytes())
        print(f"{network}: {', '.join(nodes)}; "
              f"maximum final EPANET/STACI difference {error:.6g} mg/L")


if __name__ == "__main__":
    main()
