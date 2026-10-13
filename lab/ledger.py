#!/usr/bin/env python3
"""Read `ledger.jsonl` and derive the numbers everything else quotes.

`lab/stats.py` and `site/build.py` both import this, so the README block
and the published site cannot disagree about what the lab measured.

Sizes are bytes in the ledger and MiB everywhere else, which is bytes
divided by 1048576. Dividing by 1000000 and calling the result MiB is the
mistake this lab made through ledger #48; see GOTCHAS.md.
"""

import json
import pathlib
import statistics

REPO = pathlib.Path(__file__).resolve().parent.parent
MIB = 1048576

KEPT = ("baseline", "accepted")


def mib(value):
    return value / MIB


def load(path=None):
    rows = []
    with open(path or REPO / "ledger.jsonl") as fh:
        for line in fh:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def kept(rows):
    """Baseline and accepted rows, the ones that moved the system."""
    return [r for r in rows if r["decision"] in KEPT]


def pct(before, after):
    return 0.0 if before == 0 else (before - after) * 100 / before


def series(rows):
    """One entry per numbered experiment, with sizes carried forward.

    A rejected experiment has no size of its own, and 13 of them have
    `closure_after: 0` because no system was ever built. Carrying the last
    accepted value forward is the only honest way to draw all 75: the flat
    stretches are then the rejections, which is the point.
    """
    out = []
    closure = image = boot = None
    for row in rows:
        moved = row["decision"] in KEPT and row.get("closure_after")
        if moved:
            closure = row["closure_after"]
            image = row.get("image_bytes") or image
            boot = row.get("boot_seconds") or boot
        out.append(
            {
                "id": row["id"],
                "slug": row["slug"],
                "decision": row["decision"],
                "reason": row.get("reason") or "",
                "closure_mib": mib(closure) if closure else None,
                "image_mib": mib(image) if image else None,
                "boot_seconds": boot,
                "carried": not moved,
                "saved_mib": (
                    mib(row["closure_before"] - row["closure_after"])
                    if moved and row.get("closure_before")
                    else None
                ),
            }
        )
    return out


def plateaus(rows, minimum=2):
    """Runs of consecutive experiments that moved nothing."""
    runs, run = [], []
    for row in rows:
        if row["decision"] in KEPT and row.get("closure_after"):
            if len(run) >= minimum:
                runs.append(run)
            run = []
        else:
            run.append(row["id"])
    if len(run) >= minimum:
        runs.append(run)
    return runs


def savings(rows):
    """Accepted rows by closure saved, largest first."""
    out = []
    for row in rows:
        if row["decision"] == "accepted" and row.get("closure_before"):
            out.append(
                {
                    "id": row["id"],
                    "slug": row["slug"],
                    "closure_mib": mib(row["closure_before"] - row["closure_after"]),
                    "image_mib": (
                        mib(row.get("image_before", 0) - row.get("image_bytes", 0))
                        if row.get("image_before")
                        else 0.0
                    ),
                }
            )
    return sorted(out, key=lambda r: -r["closure_mib"])


def tally(rows):
    counts = {"baseline": 0, "accepted": 0, "rejected": 0, "undecided": 0}
    for row in rows:
        counts[row["decision"]] = counts.get(row["decision"], 0) + 1
    counts["total"] = len(rows)
    return counts


def boot_spread(rows, window=10):
    """Boot time is noisy, so the lab publishes a spread, not a sample.

    REPORT.md quotes 14.141s from an e15 control and README.md quoted
    15.926s from ledger #75. Both are real and both sit inside this.
    """
    samples = [r["boot_seconds"] for r in kept(rows) if r.get("boot_seconds")]
    recent = samples[-window:]
    return {
        "window": window,
        "samples": recent,
        "mean": statistics.mean(recent),
        "sd": statistics.pstdev(recent),
        "min": min(recent),
        "max": max(recent),
        "all_min": min(samples),
        "all_max": max(samples),
    }


def headline(rows):
    first, last = kept(rows)[0], kept(rows)[-1]
    boot = boot_spread(rows)
    return {
        "closure": {
            "from_mib": mib(first["closure_after"]),
            "to_mib": mib(last["closure_after"]),
            "pct": pct(first["closure_after"], last["closure_after"]),
        },
        "image": {
            "from_mib": mib(first["image_bytes"]),
            "to_mib": mib(last["image_bytes"]),
            "pct": pct(first["image_bytes"], last["image_bytes"]),
        },
        "boot": {
            "from_seconds": first["boot_seconds"],
            "to_seconds": boot["mean"],
            "sd": boot["sd"],
            "pct": pct(first["boot_seconds"], boot["mean"]),
        },
    }
