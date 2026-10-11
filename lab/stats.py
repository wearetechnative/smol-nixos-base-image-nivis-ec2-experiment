#!/usr/bin/env python3
"""Regenerate docs/progress.svg and the stats block in README.md.

Everything here is derived from ledger.jsonl and BACKLOG.md. Nothing is
hand-maintained, so the README cannot drift from the ledger, and a number
that is not in the ledger cannot appear in the README (BRIEFING section 12).
"""

import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
MIB = 1048576

BEGIN = "<!-- STATS:BEGIN -->"
END = "<!-- STATS:END -->"

# Mid-tones only. GitHub serves the README on a light or a dark background
# and an <img> cannot know which, so every colour here has to read on both.
INK = "#8b949e"
GRID = "#8b949e40"
CLOSURE = "#3fb950"
IMAGE = "#58a6ff"
BOOT = "#d29922"


def load_ledger():
    rows = []
    with open(REPO / "ledger.jsonl") as fh:
        for line in fh:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def accepted(rows):
    return [r for r in rows if r["decision"] in ("accepted", "baseline")]


def svg(points):
    w, h = 760, 300
    ml, mr, mt, mb = 56, 16, 28, 40
    pw, ph = w - ml - mr, h - mt - mb

    ids = [p["id"] for p in points]
    ymax = max(max(p["image"] for p in points), max(p["closure"] for p in points))
    ymax = int((ymax + 299) // 300 * 300)

    def x(i):
        lo, hi = min(ids), max(ids)
        return ml + (pw if hi == lo else pw * (i - lo) / (hi - lo))

    def y(v):
        return mt + ph - ph * v / ymax

    def path(key):
        return " ".join(
            ("M" if n == 0 else "L") + f"{x(p['id']):.1f},{y(p[key]):.1f}"
            for n, p in enumerate(points)
        )

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
        f'width="{w}" height="{h}" font-family="ui-sans-serif,system-ui,sans-serif">',
        f'<rect width="{w}" height="{h}" fill="{INK}" opacity="0.06" rx="6"/>',
    ]

    step = ymax // 4
    for n in range(5):
        v = step * n
        parts.append(
            f'<line x1="{ml}" y1="{y(v):.1f}" x2="{ml + pw}" y2="{y(v):.1f}" '
            f'stroke="{GRID}" stroke-width="1"/>'
        )
        parts.append(
            f'<text x="{ml - 8}" y="{y(v) + 4:.1f}" fill="{INK}" font-size="11" '
            f'text-anchor="end">{v}</text>'
        )

    for p in points:
        parts.append(
            f'<text x="{x(p["id"]):.1f}" y="{h - 16}" fill="{INK}" font-size="10" '
            f'text-anchor="middle">{p["id"]}</text>'
        )
    parts.append(
        f'<text x="{ml + pw / 2:.1f}" y="{h - 3}" fill="{INK}" font-size="10" '
        f'text-anchor="middle">ledger entry</text>'
    )
    parts.append(
        f'<text x="14" y="{mt + ph / 2:.1f}" fill="{INK}" font-size="10" '
        f'text-anchor="middle" transform="rotate(-90 14 {mt + ph / 2:.1f})">MiB</text>'
    )

    for key, colour in (("image", IMAGE), ("closure", CLOSURE)):
        parts.append(
            f'<path d="{path(key)}" fill="none" stroke="{colour}" stroke-width="2.5" '
            f'stroke-linejoin="round" stroke-linecap="round"/>'
        )
        for p in points:
            parts.append(
                f'<circle cx="{x(p["id"]):.1f}" cy="{y(p[key]):.1f}" r="3" '
                f'fill="{colour}"/>'
            )

    first, last = points[0], points[-1]
    for key, colour, label in (
        ("image", IMAGE, "raw VHD"),
        ("closure", CLOSURE, "closure"),
    ):
        parts.append(
            f'<text x="{x(last["id"]) - 6:.1f}" y="{y(last[key]) - 10:.1f}" '
            f'fill="{colour}" font-size="12" font-weight="600" text-anchor="end">'
            f'{label} {last[key]}</text>'
        )
        parts.append(
            f'<text x="{x(first["id"]) + 6:.1f}" y="{y(first[key]) - 10:.1f}" '
            f'fill="{colour}" font-size="11" text-anchor="start">{first[key]}</text>'
        )

    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def backlog_counts():
    text = (REPO / "BACKLOG.md").read_text()
    counts = {"accepted": 0, "rejected": 0, "needs-upstream": 0, "todo": 0}
    for row in re.findall(r"^\|\s*[a-z]\d+\s*\|.*$", text, re.M):
        status = row.rsplit("|", 2)[-2].strip().lower()
        for key in ("needs-upstream", "accepted", "rejected", "todo"):
            if key in status:
                counts[key] += 1
                break
    return counts


def bar(n, total, width=28):
    filled = 0 if total == 0 else round(width * n / total)
    return "█" * filled + "·" * (width - filled)


def pct(before, after):
    return 0.0 if before == 0 else (before - after) * 100 / before


def main():
    rows = load_ledger()
    acc = accepted(rows)
    if not acc:
        sys.exit("ledger.jsonl has no accepted entries yet")

    points = [
        {
            "id": r["id"],
            "closure": round(r["closure_after"] / MIB),
            "image": round(r.get("image_bytes", 0) / MIB),
        }
        for r in acc
    ]
    (REPO / "docs").mkdir(exist_ok=True)
    (REPO / "docs" / "progress.svg").write_text(svg(points))

    base, now = acc[0], acc[-1]
    counts = backlog_counts()
    total = sum(counts.values()) or 1

    # Criterion 1 of BRIEFING section 9: the last 8 accepted experiments each
    # saved under 1 percent or under 2 MiB.
    tail = [r for r in acc if r["decision"] == "accepted"][-8:]
    small = [
        r
        for r in tail
        if (r["closure_before"] - r["closure_after"]) < 2 * MIB
        or pct(r["closure_before"], r["closure_after"]) < 1
    ]
    crit1 = len(tail) == 8 and len(small) == 8
    crit2 = counts["todo"] == 0
    floor = (REPO / "FLOOR.md").read_text()
    crit3 = "_not measured yet_" not in floor

    tick = lambda ok: "x" if ok else " "

    recent = [r for r in rows][-6:]
    log = "\n".join(
        "| {id} | `{slug}` | {c} | {i} | {d} |".format(
            id=r["id"],
            slug=r["slug"],
            c=(
                f"{(r['closure_before'] - r['closure_after']) / MIB:+.1f}"
                if r.get("closure_before")
                else "n/a"
            ),
            i=(
                f"{(r.get('image_before', 0) - r.get('image_bytes', 0)) / MIB:+.1f}"
                if r.get("image_before")
                else "n/a"
            ),
            d=("**" + r["decision"] + "**" if r["decision"] == "accepted" else r["decision"])
            + (f": {r['reason']}" if r.get("reason") else ""),
        )
        for r in recent
    )

    block = f"""{BEGIN}
## Progress

| | baseline | now | off |
| --- | --- | --- | --- |
| **closure** | {base['closure_after'] / MIB:.0f} MiB | **{now['closure_after'] / MIB:.0f} MiB** | {pct(base['closure_after'], now['closure_after']):.1f}% |
| **raw VHD** | {base['image_bytes'] / MIB:.0f} MiB | **{now['image_bytes'] / MIB:.0f} MiB** | {pct(base['image_bytes'], now['image_bytes']):.1f}% |
| **boot time** | {base['boot_seconds']:.1f}s | **{now['boot_seconds']:.1f}s** | {pct(base['boot_seconds'], now['boot_seconds']):.1f}% |

The raw VHD is what gets uploaded, imported as an EBS snapshot and stored as
an AMI. It is the number that costs money, and it is not the closure.

![size per accepted experiment](docs/progress.svg)

### Backlog

| state | n | |
| --- | --- | --- |
| accepted | {counts['accepted']} | `{bar(counts['accepted'], total)}` |
| rejected | {counts['rejected']} | `{bar(counts['rejected'], total)}` |
| needs-upstream | {counts['needs-upstream']} | `{bar(counts['needs-upstream'], total)}` |
| todo | {counts['todo']} | `{bar(counts['todo'], total)}` |

### Stop criteria (BRIEFING section 9)

- [{tick(crit1)}] the last 8 accepted experiments each saved under 1% or under 2 MiB ({len(small)} of {len(tail)})
- [{tick(crit2)}] every backlog item accepted, rejected or needs-upstream ({counts['todo']} still todo)
- [{tick(crit3)}] `FLOOR.md` justifies every remaining path over 1 MiB

### Last six ledger entries

| id | strategy | closure MiB | image MiB | decision |
| --- | --- | --- | --- | --- |
{log}

Full history in [`ledger.jsonl`](ledger.jsonl), one note per experiment in
[`experiments/`](experiments/).
{END}"""

    readme = REPO / "README.md"
    text = readme.read_text()
    if BEGIN in text and END in text:
        text = re.sub(
            re.escape(BEGIN) + r".*?" + re.escape(END), lambda _: block, text, flags=re.S
        )
    else:
        text = text.rstrip() + "\n\n" + block + "\n"
    readme.write_text(text)
    print(f"docs/progress.svg and README.md updated from {len(rows)} ledger entries")


if __name__ == "__main__":
    main()
