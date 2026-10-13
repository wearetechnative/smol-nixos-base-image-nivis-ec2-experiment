#!/usr/bin/env python3
"""Checks on the published site. This is the gate the lab's two cannot be.

The lab's gates boot machines. A static page has no boot, so what is
checked here is the only thing that can go wrong with it: that it stops
saying what the data says, or stops being readable without motion and
without scripting.

    python3 site/verify.py
"""

import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(REPO / "lab"))

import ledger  # noqa: E402

FAILURES = []


def check(name, condition, detail=""):
    if condition:
        print(f"ok   {name}")
    else:
        print(f"FAIL {name}" + (f": {detail}" if detail else ""))
        FAILURES.append(name)


def visible(page):
    """The page as a reader sees it: no scripts, no styles, no attributes."""
    body = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", page, flags=re.S)
    return re.sub(r"<[^>]+>", " ", body)


def main():
    page = (HERE / "index.html").read_text()
    css = (HERE / "style.css").read_text()
    js = (HERE / "main.js").read_text()
    data = json.loads((HERE / "data.json").read_text())
    text = visible(page)
    rows = ledger.load()

    # ---- the numbers are the data's numbers
    head = data["headline"]
    for label, value in (
        ("final closure", round(head["closure"]["to_mib"])),
        ("baseline closure", round(head["closure"]["from_mib"])),
        ("final image", round(head["image"]["to_mib"])),
    ):
        pretty = f"{value:,}".replace(",", " ")
        check(f"{label} is on the page", pretty in text, f"expected {pretty}")

    fresh = ledger.headline(rows)
    check(
        "data.json matches ledger.jsonl",
        abs(fresh["closure"]["to_mib"] - head["closure"]["to_mib"]) < 1e-9,
        "rebuild with `just site`",
    )

    # ---- boot is published as a spread, not as a sample
    spread = data["boot_spread"]
    check(
        "boot is stated with its spread",
        f"{spread['sd']:.1f}" in text and f"{spread['min']:.1f}" in text,
        "the page must show the deviation and the range",
    )
    for sample in ("14.141", "15.926"):
        check(
            f"no single boot run ({sample}) is presented as the result",
            sample not in text,
        )

    # ---- README, REPORT and the site agree on boot
    readme = (REPO / "README.md").read_text()
    report = (REPO / "REPORT.md").read_text()
    claimed = f"{spread['mean']:.1f}s"
    check(
        "README states the same boot figure as the site",
        claimed in readme,
        f"README should state {claimed}",
    )
    check(
        "REPORT states the same boot figure as the site",
        claimed in report,
        f"REPORT should state {claimed}",
    )

    # ---- the rejections are visible
    counts = data["tally"]
    check("the rejections are counted on the page", str(counts["rejected"]) in text)
    check("the undecided are counted on the page", str(counts["undecided"]) in text)
    ticks = page.count('class="reject-tick"')
    check(
        "every rejection has a tick on the descent",
        ticks == counts["rejected"] + counts["undecided"],
        f"{ticks} ticks for {counts['rejected'] + counts['undecided']} non-accepted",
    )
    plateaus = page.count('class="plateau"')
    check(
        "every plateau is drawn",
        plateaus == len(data["plateaus"]),
        f"{plateaus} drawn, {len(data['plateaus'])} in the data",
    )

    # ---- the annotated wins are the real ones
    for win in data["wins"]:
        check(
            f"win {win['slug']} is labelled with its measured saving",
            f'>{win["slug"]} <' in page and f'{win["closure_mib"]:,.0f}'.replace(",", " ") in page,
        )

    # ---- charts are server-rendered, so they survive without scripting
    body_without_js = re.sub(r"<script.*?</script>", "", page, flags=re.S)
    for chart in ("chart--descent", "chart--bars", "chart--boot"):
        check(f"{chart} renders without JavaScript", chart in body_without_js)
    check(
        "the counter is the only thing JavaScript adds",
        "createElement" not in js and "innerHTML" not in js,
        "main.js must not build content",
    )

    # ---- motion is optional
    check(
        "animation is behind prefers-reduced-motion: no-preference",
        "@media (prefers-reduced-motion: no-preference)" in css,
    )
    guarded = css.split("@media (prefers-reduced-motion: no-preference)")[1]
    stray = [
        line
        for line in css.split("@media (prefers-reduced-motion: no-preference)")[0].split("\n")
        if "animation:" in line or "@keyframes" in line
    ]
    check("no animation outside that guard", not stray, "; ".join(stray))
    check("the guarded block is where the keyframes live", "@keyframes" in guarded)

    # ---- framing
    check("nivis is named exactly once", len(re.findall("nivis", text, re.I)) == 1)
    check("ElastiNix is named", "elastinix" in text.lower())
    for claim in ("production-ready", "drop-in", "ready to use"):
        check(f"no overclaim: {claim!r}", claim not in text.lower())

    # ---- self-contained
    external = re.findall(r'(?:href|src)="(https?://[^"]+)"', page)
    assets = [u for u in external if not u.startswith("https://github.com/")]
    check("no third-party asset is loaded", not assets, ", ".join(assets))

    print()
    if FAILURES:
        print(f"{len(FAILURES)} check(s) failed")
        return 1
    print("all site checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
