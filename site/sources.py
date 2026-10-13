#!/usr/bin/env python3
"""Read the prose sources: REPORT.md and the experiment notes.

`ledger.jsonl` carries the experiment series and `lab/ledger.py` reads it.
Everything here is the other half: the floor table, the upstream findings,
the rejection groups, and the boot controls that were measured but were
deliberately never ledger lines.

Nothing in this file holds a number. Every value is parsed out of the
file it is quoted from, so a figure cannot drift from its source, and a
heading that moves breaks the build instead of silently publishing a
stale table.
"""

import pathlib
import re

REPO = pathlib.Path(__file__).resolve().parent.parent


def _section(text, heading):
    """The body of one `## ` section, by its exact heading line."""
    start = text.index(heading)
    nxt = text.find("\n## ", start + len(heading))
    return text[start : nxt if nxt != -1 else len(text)]


def _table(section):
    """Rows of the first markdown table in a section, cells stripped."""
    rows = []
    for line in section.split("\n"):
        line = line.strip()
        if not line.startswith("|"):
            if rows:
                break
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if all(set(c) <= set("- :") for c in cells):
            continue
        rows.append(cells)
    return rows


def _demarkdown(text):
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"\*\*([^*]*)\*\*", r"\1", text)
    text = re.sub(r"\*([^*]*)\*", r"\1", text)
    return " ".join(text.split())


def floor(report):
    """REPORT section 3: what is left and why it cannot go."""
    rows = _table(_section(report, "## 3. The floor"))
    header, body = rows[0], rows[1:]
    if [c.lower() for c in header] != ["mib", "what"]:
        raise SystemExit("REPORT section 3: expected a MiB/what table, got " + str(header))
    out = [{"mib": float(mib), "what": _demarkdown(what)} for mib, what in body]
    if not out:
        raise SystemExit("REPORT section 3: no floor rows parsed")
    return sorted(out, key=lambda r: -r["mib"])


def upstream(report):
    """REPORT section 5: the four findings that belong in nixpkgs."""
    section = _section(report, "## 5. What belongs upstream")
    items = re.findall(r"^\d+\. \*\*(.+?)\*\*(.*?)(?=^\d+\. |\Z)", section, re.S | re.M)
    out = []
    for title, rest in items:
        body = _demarkdown(rest)
        ref = re.search(r"(Ledger #\d+|Backlog e\d+)", body)
        out.append(
            {
                "title": _demarkdown(title).rstrip("."),
                "body": body,
                "reference": ref.group(1) if ref else "",
            }
        )
    if len(out) != 4:
        raise SystemExit("REPORT section 5: expected 4 findings, parsed %d" % len(out))
    return out


def rejection_groups(report):
    """REPORT section 4: the four kinds of rejection, with their counts."""
    section = _section(report, "## 4. What did not work")
    found = re.findall(r"\*\*(.+?) \((\d+)\)\.\*\*(.*?)(?=\n\n)", section, re.S)
    out = [
        {"name": _demarkdown(n), "count": int(c), "body": _demarkdown(b)}
        for n, c, b in found
    ]
    if not out:
        raise SystemExit("REPORT section 4: no rejection groups parsed")
    return out


def boot_controls(note=None):
    """The e15 runs: one closure, three images, measured not logged.

    These never became ledger lines because nothing was accepted or
    rejected on them, and they are the clearest result the lab has about
    boot time. The site labels them as controls for that reason.
    """
    path = pathlib.Path(note or REPO / "experiments" / "e15-boot-time.md")
    rows = _table(_section(path.read_text(), "## What was tested"))
    header, body = rows[0], rows[1:]
    if [c.lower() for c in header] != ["image", "virtual size", "vhd file", "boot"]:
        raise SystemExit("e15 note: unexpected table header " + str(header))
    out = []
    for image, virtual, vhd, boot in body:
        out.append(
            {
                "label": _demarkdown(image),
                "virtual": _demarkdown(virtual),
                "vhd_mb": float(re.search(r"([\d.]+)", vhd).group(1)),
                "boot_seconds": float(re.search(r"([\d.]+)", boot).group(1)),
            }
        )
    if len(out) != 3:
        raise SystemExit("e15 note: expected 3 controls, parsed %d" % len(out))
    return {"source": "experiments/e15-boot-time.md", "runs": out}
