#!/usr/bin/env python3
"""Build the results site from the repository's own data.

    python3 site/build.py            write site/data.json and site/index.html
    python3 site/build.py --check    rebuild and fail if the committed
                                     output differs, or if the page source
                                     contains a quantity the data did not
                                     produce

Two inputs, and they are not interchangeable. `ledger.jsonl` carries the
experiment series. `REPORT.md` and the experiment notes carry the stated
facts and the controls, which were measured and deliberately never became
ledger lines. Mixing them would let a later editor "reconcile" the site to
the ledger and silently delete the e15 result.
"""

import argparse
import html
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(REPO / "lab"))
sys.path.insert(0, str(HERE))

import charts  # noqa: E402
import copy as prose  # noqa: E402
import ledger  # noqa: E402
import sources  # noqa: E402

REPO_URL = "https://github.com/wearetechnative/smol-nixos-base-image-nivis-ec2-experiment"
WINS = 8
BARS = 12

# A number on the page that the data did not produce is a lie waiting to
# happen. The check greps the prose and the template for these.
QUANTITY = re.compile(
    r"(?<![\w{])\d[\d\s.,]*\s*(MiB|MB|GiB|KiB|bytes|%|s\b|seconds|experiments)",
    re.I,
)


def esc(value):
    return html.escape(str(value), quote=True)


def fmt(value, places=0):
    return f"{value:,.{places}f}".replace(",", " ")


def collect():
    """Everything the page says, derived, in one structure."""
    rows = ledger.load()
    report = (REPO / "REPORT.md").read_text()

    head = ledger.headline(rows)
    spread = ledger.boot_spread(rows)
    series = ledger.series(rows)
    saved = ledger.savings(rows)
    plateau = ledger.plateaus(rows)
    counts = ledger.tally(rows)

    total_saved = sum(s["closure_mib"] for s in saved)
    top6 = saved[:6]

    # "everything after the big six", to size the long tail honestly
    tail = saved[6:]

    stc = next(s for s in saved if s["slug"] == "no-switch-to-configuration")
    xz = next(s for s in saved if s["slug"] == "xz-initrd")
    xz_row = next(r for r in rows if r["slug"] == "xz-initrd" and r["decision"] == "accepted")
    xz_before = next(
        r for r in ledger.kept(rows) if r["id"] < xz_row["id"] and r.get("boot_seconds")
    )
    for r in ledger.kept(rows):
        if r["id"] < xz_row["id"] and r.get("boot_seconds"):
            xz_before = r

    controls = sources.boot_controls()
    runs = controls["runs"]

    packages = re.search(r"(\d+) packages on the system path", report)
    options = len(list((REPO / "modules" / "smol").glob("*.nix"))) - 2

    data = {
        "generated_from": {
            "ledger": "ledger.jsonl",
            "report": "REPORT.md",
            "controls": controls["source"],
        },
        "headline": head,
        "boot_spread": spread,
        "series": series,
        "plateaus": plateau,
        "savings": saved,
        "wins": saved[:WINS],
        "tally": counts,
        "insight": {
            "top6_mib": sum(s["closure_mib"] for s in top6),
            "total_mib": total_saved,
            "pct": 100 * sum(s["closure_mib"] for s in top6) / total_saved,
            "strategies": [s["slug"] for s in top6],
            "tail_mib": sum(s["closure_mib"] for s in tail),
            "tail_count": len(tail),
        },
        "floor": sources.floor(report),
        "upstream": sources.upstream(report),
        "rejection_groups": sources.rejection_groups(report),
        "boot_controls": controls,
        "references": {
            "switch_to_configuration_mib": stc["closure_mib"],
            "xz_saving_mib": xz["closure_mib"],
            "xz_boot_cost": xz_row["boot_seconds"] - xz_before["boot_seconds"],
            "packages_on_path": int(packages.group(1)) if packages else None,
            "smol_options": options,
        },
    }
    return data


def slots(data):
    """Every value the prose and the template may interpolate."""
    head = data["headline"]
    spread = data["boot_spread"]
    counts = data["tally"]
    insight = data["insight"]
    runs = data["boot_controls"]["runs"]
    ref = data["references"]
    longest = max(data["plateaus"], key=len)

    return {
        "closure_from": fmt(head["closure"]["from_mib"]),
        "closure_to": fmt(head["closure"]["to_mib"]),
        "closure_pct": fmt(head["closure"]["pct"]),
        "image_from": fmt(head["image"]["from_mib"]),
        "image_to": fmt(head["image"]["to_mib"]),
        "image_pct": fmt(head["image"]["pct"]),
        "boot_from": fmt(head["boot"]["from_seconds"], 1),
        "boot_to": fmt(head["boot"]["to_seconds"], 1),
        "boot_sd": fmt(head["boot"]["sd"], 1),
        "boot_pct": fmt(head["boot"]["pct"]),
        "boot_window": str(spread["window"]),
        "boot_min": fmt(spread["min"], 1),
        "boot_max": fmt(spread["max"], 1),
        "n_total": str(counts["total"]),
        "n_accepted": str(counts["accepted"]),
        "n_rejected": str(counts["rejected"]),
        "n_undecided": str(counts["undecided"]),
        "top6_mib": fmt(insight["top6_mib"]),
        "total_mib": fmt(insight["total_mib"]),
        "late_savings": fmt(insight["tail_mib"]),
        "late_count": str(insight["tail_count"]),
        "longest_plateau": "%d to %d" % (longest[0], longest[-1]),
        "stc_saving": fmt(ref["switch_to_configuration_mib"]),
        "xz_cost": fmt(ref["xz_boot_cost"], 1),
        "xz_saving": fmt(ref["xz_saving_mib"], 2),
        "n_packages": str(ref["packages_on_path"]),
        "n_options": str(ref["smol_options"]),
        "channel_mb": fmt(runs[-1]["vhd_mb"] - runs[0]["vhd_mb"]),
        "channel_cost": fmt(runs[-1]["boot_seconds"] - runs[1]["boot_seconds"], 2),
    }


def check_prose():
    """No quantity may be written into the prose or the template."""
    offenders = []
    for path in (HERE / "copy.py", HERE / "template.html"):
        for n, line in enumerate(path.read_text().split("\n"), 1):
            if path.suffix == ".py" and line.lstrip().startswith("#"):
                continue
            stripped = re.sub(r"\{\{[a-z_]+\}\}|\{[a-z_0-9]+\}", "", line)
            for hit in QUANTITY.finditer(stripped):
                offenders.append(f"{path.name}:{n}: {hit.group(0).strip()!r} in {line.strip()!r}")
    return offenders


def render(data):
    s = slots(data)
    template = (HERE / "template.html").read_text()

    body = {
        "title": prose.TITLE,
        "meta_description": prose.META.format(**s),
        "eyebrow": prose.EYEBROW,
        "hero_title": prose.HERO_TITLE.format(**s),
        "hero_lede": prose.HERO_LEDE.format(**s),
        "hero_note": prose.HERO_NOTE.format(**s),
        "question_lead": prose.QUESTION_LEAD.format(**s),
        "question_body": prose.QUESTION_BODY.format(**s),
        "method_items": "\n    ".join(
            f"<li>{esc(item.format(**s))}</li>" for item in prose.METHOD
        ),
        "method_note": prose.METHOD_NOTE.format(**s),
        "descent_lead": prose.DESCENT_LEAD.format(**s),
        "descent_note": prose.DESCENT_NOTE.format(**s),
        "descent_svg": charts.descent(data["series"], data["wins"], data["plateaus"]),
        "insight_pull": prose.INSIGHT_PULL.format(**s),
        "insight_body": prose.INSIGHT_BODY.format(**s),
        "bars_svg": charts.bars(data["savings"], BARS),
        "boot_lead": prose.BOOT_LEAD.format(**s),
        "boot_note": prose.BOOT_NOTE.format(**s),
        "boot_svg": charts.boot_controls(data["boot_controls"]),
        "floor_lead": prose.FLOOR_LEAD.format(**s),
        "floor_rows": "\n      ".join(
            f'<tr><td class="num">{fmt(row["mib"], 2)}</td><td>{esc(row["what"])}</td></tr>'
            for row in data["floor"]
        ),
        "tally_items": "\n    ".join(
            f'<div class="tally-item tally-item--{key}">'
            f'<span class="tally-n">{data["tally"][key]}</span> '
            f'<span class="tally-k">{key}</span></div>'
            for key in ("baseline", "accepted", "rejected", "undecided")
        ),
        "tally_pull": prose.TALLY_PULL.format(**s),
        "rejection_groups": "\n    ".join(
            f'<li><span class="group-n">{g["count"]}</span> '
            f'<span class="group-name">{esc(g["name"])}</span> '
            f'<span class="group-body">{esc(g["body"])}</span></li>'
            for g in data["rejection_groups"]
        ),
        "upstream_lead": prose.UPSTREAM_LEAD.format(**s),
        "upstream_items": "\n    ".join(
            f'<li><h3>{esc(u["title"])}</h3><p>{esc(u["body"])}</p></li>'
            for u in data["upstream"]
        ),
        "next_lead": prose.NEXT_LEAD.format(**s),
        "next_body": prose.NEXT_BODY.format(**s),
        "footer_provenance": prose.FOOTER_PROVENANCE.format(**s),
        "footer_brand": prose.FOOTER_BRAND,
        "repo_url": REPO_URL,
        "repo_label": "the repository",
        "report_url": REPO_URL + "/blob/main/REPORT.md",
        "report_label": "the report",
        "ledger_url": REPO_URL + "/blob/main/ledger.jsonl",
        "ledger_label": "the ledger",
    }

    # the template may also place a bare quantity, so the slots are
    # available to it directly
    body = dict(s, **body)

    out = template
    for key, value in body.items():
        out = out.replace("{{%s}}" % key, str(value))

    left = re.findall(r"\{\{[a-z_]+\}\}", out)
    if left:
        raise SystemExit("unfilled slots in template: " + ", ".join(sorted(set(left))))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="verify, do not write")
    args = ap.parse_args()

    offenders = check_prose()
    if offenders:
        print("a quantity was written by hand instead of derived:", file=sys.stderr)
        for line in offenders:
            print("  " + line, file=sys.stderr)
        raise SystemExit(1)

    data = collect()
    page = render(data)
    blob = json.dumps(data, indent=2, sort_keys=True) + "\n"

    data_path, page_path = HERE / "data.json", HERE / "index.html"
    if args.check:
        bad = False
        for path, fresh in ((data_path, blob), (page_path, page)):
            if not path.exists():
                print(f"{path.name} is missing", file=sys.stderr)
                bad = True
            elif path.read_text() != fresh:
                print(f"{path.name} differs from what the data produces", file=sys.stderr)
                bad = True
        if bad:
            raise SystemExit("run `just site` and commit the result")
        print("site is in step with the data")
        return

    data_path.write_text(blob)
    page_path.write_text(page)
    print(
        "site/index.html and site/data.json built from %s ledger lines"
        % data["tally"]["total"]
    )


if __name__ == "__main__":
    main()
