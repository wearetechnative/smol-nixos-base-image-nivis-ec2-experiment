# results-site Specification

## Purpose

The published results site: what it must contain, where each number on it
comes from, and what has to stay true when the underlying data changes.
These are contracts about provenance and legibility, not about layout or
motion.

## Requirements

### Requirement: Every published number is derived, never typed

The site SHALL obtain each quantity it displays from `ledger.jsonl`,
`REPORT.md` or a file under `experiments/`, through the build, and SHALL
NOT contain a hand-written figure. MiB SHALL be bytes divided by 1048576.

#### Scenario: A ledger line changes

- **WHEN** a value in `ledger.jsonl` changes and the site is rebuilt
- **THEN** every figure, chart and label derived from it changes with it
- **AND** no published figure keeps its previous value

#### Scenario: A figure is typed into the page source

- **WHEN** the build runs against a page source containing a literal
  quantity that the data does not produce
- **THEN** the build fails and names the figure it could not derive

#### Scenario: Bytes are converted

- **WHEN** a size is published
- **THEN** it is bytes divided by 1048576, labelled MiB, and not bytes
  divided by 1000000

### Requirement: The source of each class of number is explicit

The build SHALL take the experiment series from `ledger.jsonl`, and SHALL
take any measurement that was never an experiment, such as the boot-time
controls in `experiments/e15-boot-time.md`, from its own file. The site
SHALL distinguish the two so that a reader can tell a logged experiment
from a control run.

#### Scenario: A control run is shown

- **WHEN** the site shows a measurement that has no ledger id
- **THEN** it is labelled as a control rather than as an experiment
- **AND** the file it came from is identified

#### Scenario: Someone reconciles the site to the ledger alone

- **WHEN** a later editor removes everything that is not in `ledger.jsonl`
- **THEN** the loss is visible, because the controls are labelled and
  named rather than mixed into the series

### Requirement: Uncertainty is published, not hidden

Where the repository contains several measurements of one quantity and
they disagree by more than their spread, the site SHALL state the spread
rather than selecting one value. This applies to boot time, where the last
ten accepted experiments range from 12.8 to 15.9 seconds.

#### Scenario: Boot time is stated

- **WHEN** the site states a final boot time
- **THEN** it states a central value together with its spread
- **AND** it does not present a single run as the result

#### Scenario: The image measurement is small

- **WHEN** an image delta below the measurement granularity is shown
- **THEN** the site says that the VHD is sparse and rounded, so that a
  reader does not treat a 2 MiB step as a result

### Requirement: The page reads without motion and without JavaScript

The site SHALL present its full content, in order, when
`prefers-reduced-motion: reduce` is set, and SHALL remain readable when
JavaScript does not run. Motion SHALL be decoration over content that is
already there.

#### Scenario: Reduced motion is requested

- **WHEN** a visitor has `prefers-reduced-motion: reduce`
- **THEN** every section, number, chart and annotation is present and
  legible
- **AND** nothing animates

#### Scenario: JavaScript is unavailable

- **WHEN** the page is loaded with scripting disabled
- **THEN** the narrative, the figures and the charts' content are still
  readable

### Requirement: The rejections are visible in the result

The site SHALL show the 33 rejected and 2 undecided experiments alongside
the 39 accepted ones, and SHALL NOT present the descent as a sequence of
successes. Where the size curve is flat because an experiment was
rejected, that SHALL be legible.

#### Scenario: The descent is drawn over all experiments

- **WHEN** size is plotted across the 75 numbered experiments
- **THEN** the stretches with no movement correspond to rejections
- **AND** a reader can see which experiment ids they were

#### Scenario: The tally is stated

- **WHEN** the site reports how many experiments ran
- **THEN** it reports 1 baseline, 39 accepted, 33 rejected and 2
  undecided, and says that six of the rejections were the lab's own
  defects

### Requirement: The site is self-contained and stable

The site SHALL be static, SHALL be served from this repository by GitHub
Pages, and SHALL depend on no third-party runtime service for its content.
Its URL SHALL be stable enough for the blog post and the Discourse thread
to link to.

#### Scenario: The site is published

- **WHEN** `main` is updated and the workflow runs
- **THEN** the site is deployed and its URL serves the page

#### Scenario: An external service is unavailable

- **WHEN** the page is loaded with no access to any host other than the
  one serving it
- **THEN** the content, the charts and the typography still render

### Requirement: The framing matches what the lab proved

The site SHALL present the measured strategies as the reusable result, and
SHALL NOT claim that a production-ready configurable base image exists.
nivis SHALL be named once, as the deployment mechanism the lab used.
ElastiNix SHALL be named as direction rather than as a finished claim.

#### Scenario: The forward line is read

- **WHEN** a reader reaches the end of the page
- **THEN** they understand that the strategies and their measurements are
  the deliverable, and that the configurable image is the next project

#### Scenario: nivis is mentioned

- **WHEN** the page body names nivis
- **THEN** it does so once, as the mechanism, and not as the subject
