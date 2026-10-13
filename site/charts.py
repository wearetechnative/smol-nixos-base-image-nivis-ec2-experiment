#!/usr/bin/env python3
"""Inline SVG, drawn from the data.

Every chart renders complete. Motion is added later by CSS, over a
picture that is already correct, which is what lets the page be read with
scripting off and with `prefers-reduced-motion: reduce`.
"""

import html


def _esc(text):
    return html.escape(str(text), quote=True)


def _fmt(value, places=0):
    return f"{value:,.{places}f}".replace(",", " ")


def descent(series, wins, plateaus):
    """Closure across all 75 experiments, carried flat through rejections.

    The flat stretches are the rejections. A smooth curve over the 40
    accepted rows hides the lab: the plateau at 20 to 24 is where
    switch-to-configuration was given up on, and experiment 45 came back
    to it for 134 MiB.
    """
    w, h = 1000, 420
    ml, mr, mt, mb = 64, 18, 26, 64
    pw, ph = w - ml - mr, h - mt - mb
    rail = h - mb + 22

    ids = [p["id"] for p in series]
    lo, hi = min(ids), max(ids)
    top = max(p["closure_mib"] for p in series if p["closure_mib"])
    ymax = int((top + 199) // 200 * 200)

    def x(i):
        return ml + pw * (i - lo) / (hi - lo)

    def y(v):
        return mt + ph - ph * v / ymax

    parts = [
        f'<svg class="chart chart--descent" viewBox="0 0 {w} {h}" '
        f'role="img" aria-label="Closure size across all {len(series)} experiments">'
    ]

    for n in range(5):
        v = ymax * n / 4
        parts.append(
            f'<line class="grid" x1="{ml}" y1="{y(v):.1f}" x2="{ml + pw}" y2="{y(v):.1f}"/>'
            f'<text class="tick" x="{ml - 10}" y="{y(v) + 4:.1f}" text-anchor="end">{_fmt(v)}</text>'
        )
    parts.append(f'<text class="axis" x="{ml - 10}" y="{mt - 12}" text-anchor="end">MiB</text>')

    # step path: a horizontal hold through every rejection, then the drop
    d = []
    prev = None
    for p in series:
        if p["closure_mib"] is None:
            continue
        px, py = x(p["id"]), y(p["closure_mib"])
        if prev is None:
            d.append(f"M{px:.1f},{py:.1f}")
        else:
            d.append(f"L{px:.1f},{prev:.1f}L{px:.1f},{py:.1f}")
        prev = py
    path = " ".join(d)
    parts.append(f'<path class="descent-line" d="{path}"/>')

    for run in plateaus:
        x0, x1 = x(run[0]) - 3, x(run[-1]) + 3
        parts.append(
            f'<rect class="plateau" x="{x0:.1f}" y="{mt}" width="{x1 - x0:.1f}" height="{ph}"/>'
        )

    for p in series:
        if p["decision"] in ("rejected", "undecided"):
            parts.append(
                f'<line class="reject-tick" x1="{x(p["id"]):.1f}" y1="{rail - 7}" '
                f'x2="{x(p["id"]):.1f}" y2="{rail + 7}"><title>'
                f'#{p["id"]} {_esc(p["slug"])}: {_esc(p["reason"] or p["decision"])}'
                f"</title></line>"
            )
    parts.append(
        f'<text class="axis" x="{ml - 10}" y="{rail + 4}" text-anchor="end">rejected</text>'
    )

    for n, win in enumerate(wins):
        p = next(s for s in series if s["id"] == win["id"])
        wx, wy = x(win["id"]), y(p["closure_mib"])
        up = 18 + (n % 3) * 20
        parts.append(
            f'<g class="win" style="--i:{n}">'
            f'<circle class="win-dot" cx="{wx:.1f}" cy="{wy:.1f}" r="4"/>'
            f'<line class="win-stem" x1="{wx:.1f}" y1="{wy:.1f}" x2="{wx:.1f}" y2="{wy - up:.1f}"/>'
            f'<text class="win-label" x="{wx + 6:.1f}" y="{wy - up - 4:.1f}">'
            f'{_esc(win["slug"])} <tspan class="win-value">{_fmt(win["closure_mib"])}</tspan>'
            f"</text></g>"
        )

    for i in range(lo, hi + 1, 10):
        parts.append(
            f'<text class="tick" x="{x(i):.1f}" y="{h - 16}" text-anchor="middle">{i}</text>'
        )
    parts.append(
        f'<text class="axis" x="{ml + pw / 2:.1f}" y="{h - 2}" text-anchor="middle">experiment</text>'
    )
    parts.append("</svg>")
    return "\n".join(parts)


def bars(savings, limit=12):
    """Where it went, longest first."""
    rows = savings[:limit]
    top = rows[0]["closure_mib"]
    rh, gap = 26, 10
    w = 1000
    ml, mr = 210, 90
    h = len(rows) * (rh + gap) + 10
    parts = [
        f'<svg class="chart chart--bars" viewBox="0 0 {w} {h}" role="img" '
        f'aria-label="Closure saved by the {len(rows)} largest strategies">'
    ]
    for n, row in enumerate(rows):
        y = n * (rh + gap)
        bw = (w - ml - mr) * row["closure_mib"] / top
        parts.append(
            f'<g class="bar" style="--i:{n}">'
            f'<text class="bar-name" x="{ml - 12}" y="{y + rh - 7}" text-anchor="end">'
            f'{_esc(row["slug"])}</text>'
            f'<rect class="bar-rect" x="{ml}" y="{y}" width="{bw:.1f}" height="{rh}" rx="2"/>'
            f'<text class="bar-value" x="{ml + bw + 10:.1f}" y="{y + rh - 7}">'
            f'{_fmt(row["closure_mib"], 1)}</text>'
            f"</g>"
        )
    parts.append("</svg>")
    return "\n".join(parts)


def boot_controls(controls):
    """One closure, three images, three boots. The line is flat."""
    runs = controls["runs"]
    w, h = 1000, 300
    ml, mr, mt, mb = 70, 40, 30, 60
    pw, ph = w - ml - mr, h - mt - mb
    xmax = max(r["vhd_mb"] for r in runs) * 1.12
    ymax = 20.0

    def x(v):
        return ml + pw * v / xmax

    def y(v):
        return mt + ph - ph * v / ymax

    parts = [
        f'<svg class="chart chart--boot" viewBox="0 0 {w} {h}" role="img" '
        f'aria-label="Boot time against image size for three control runs">'
    ]
    for v in (0, 5, 10, 15, 20):
        parts.append(
            f'<line class="grid" x1="{ml}" y1="{y(v):.1f}" x2="{ml + pw}" y2="{y(v):.1f}"/>'
            f'<text class="tick" x="{ml - 10}" y="{y(v) + 4:.1f}" text-anchor="end">{v}s</text>'
        )
    first, last = runs[0], runs[-1]
    parts.append(
        f'<line class="boot-trend" x1="{x(first["vhd_mb"]):.1f}" y1="{y(first["boot_seconds"]):.1f}" '
        f'x2="{x(last["vhd_mb"]):.1f}" y2="{y(last["boot_seconds"]):.1f}"/>'
    )
    for n, r in enumerate(runs):
        cx, cy = x(r["vhd_mb"]), y(r["boot_seconds"])
        parts.append(
            f'<g class="boot-point" style="--i:{n}">'
            f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="7"/>'
            f'<text class="boot-value" x="{cx:.1f}" y="{cy - 16:.1f}" text-anchor="middle">'
            f'{r["boot_seconds"]:.2f}s</text>'
            f'<text class="tick" x="{cx:.1f}" y="{h - 26}" text-anchor="middle">'
            f'{_fmt(r["vhd_mb"])} MB</text>'
            f"<title>{_esc(r['label'])}</title>"
            f"</g>"
        )
    parts.append(
        f'<text class="axis" x="{ml + pw / 2:.1f}" y="{h - 4}" text-anchor="middle">'
        f"image size</text>"
    )
    parts.append("</svg>")
    return "\n".join(parts)
