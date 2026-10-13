# Changelog

Notable changes to this repository. The lab's own results are in
`REPORT.md` and `ledger.jsonl`; this file records changes to what the
repository publishes and how.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- A results site at
  <https://wearetechnative.github.io/smol-nixos-base-image-nivis-ec2-experiment/>,
  built from `ledger.jsonl`, `REPORT.md` and the experiment notes, with
  the descent drawn across all 75 experiments so the rejections are
  visible. `just site` rebuilds it and `just site-check` fails if the
  published page has drifted from the data.
- The repository's first CI: a GitHub Actions workflow that verifies the
  site against the data on every push and deploys it to GitHub Pages from
  `main`.

### Changed

- Boot time is stated as a spread, 14.3s with a standard deviation of
  0.9, in `README.md`, `REPORT.md` and on the site. The three previously
  disagreed: the report quoted a control run at 14.1s and the README
  quoted ledger #75 at 15.9s, and both are samples from a range of 12.8
  to 15.9 seconds.
