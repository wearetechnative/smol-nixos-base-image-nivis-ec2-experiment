# BRIEFING — smol NixOS base image (nivis → EC2) experiment

Repo: https://github.com/wearetechnative/smol-nixos-base-image-nivis-ec2-experiment
Owner: Pim Snel (mipmip)

This file is the complete brief for Claude Code. Read it fully at the start of
every session, together with `STATE.md`. It is the source of truth; if anything
in the repo contradicts it, this file wins until Pim changes it.

---

## 1. Mission

Find out how small our NixOS base image for AWS EC2 can realistically get while
it still boots on EC2, is deployed through **nivis**, and is fully functional
over SSH.

Every size-reduction strategy you find must end up as a **NixOS module option**
under `smol.*`, with a proper description, measured savings, trade-offs and
known pitfalls. The repo must document itself: anyone reading the ledger,
`REPORT.md` and the generated option docs must understand what was tried, what
worked, what failed, and why.

We do not know the theoretical minimum. You keep going until the stop criteria
in §9 are met, so we can say with evidence: *this is realistically the bottom*.

---

## 2. Prior art (read these first, cite them in module descriptions)

- natkr, "I can haz smoller NixOS ISOs?" — https://natkr.com/2026-06-19-nixos-but-smol/
  ISO 458 → 183 MiB: `nix.enable = false`, `documentation.enable = false`,
  `programs.ssh` option stub + `disabledModules`, `environment.defaultPackages = []`,
  trimming `systemPackages` / `system.extraDependencies`, removing
  `$out/kernel-modules`, `system.etc.overlay` + `services.userborn` to drop Perl.
- siraben, "Smallest bootable NixOS ISO (~91 MiB)" —
  https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6
  183 → 91 MiB, each step boot-verified via QEMU serial console. Slim systemd
  and minimal util-linux **as nixpkgs overlays**, dbus without X11 and reusing
  slim systemd, xz squashfs/initrd/kernel, initrd module trim,
  `system.switch.enable = false`, C.UTF-8 only, lastlog off (drops sqlite),
  empty hwdb, etc. Its results table is the model for our ledger.
- xerz-one/nixos-systems — https://github.com/xerz-one/nixos-systems
  Flake template: one subdirectory per system. Use the idea for `systems/`.
- benjumanji/nixos-smol — not about size (npins + specialArgs). Ignore for
  strategies.

**Important difference with prior art:** those images dropped networking, sshd
and most kernel modules because they only needed a local root shell. We need
networking, DHCP, sshd, EC2 metadata (SSH key injection) and EC2 storage/network
drivers. Expect our floor to be higher than 91 MiB. Finding out how much higher
is the point.

---

## 3. Target and definition of "fully functional"

- Platform: AWS EC2, x86_64, Nitro (default test type: `t3.micro`).
  Optional later: one Xen-based type, and arm64 (Graviton) as a separate track.
- Deployment: **through nivis**, not through hand-written AWS calls (see §6).
- Region: ask Pim in phase 0, record it in `lab/config.env`.

`lab/verify.sh` is the contract. A candidate passes only if, over SSH:

1. Key-based SSH login works with a key injected from EC2 metadata (not baked in).
2. `systemctl is-system-running` returns `running`, no failed units.
3. DNS resolution and outbound HTTPS work, the clock is synced.
4. Root filesystem is mounted read-write and has the expected size.
5. The instance survives a reboot and passes 1–4 again.
6. *Mutable track only:* `nixos-rebuild switch` (or nivis' equivalent update path) works.

The contract is versioned. Changing it requires Pim's approval and a new
ledger "epoch" (all previous results stay valid only for the old contract).

### Tracks

- **appliance** (primary): no Nix on target, immutable `/etc`, no
  switch-to-configuration. Updates happen by replacing the AMI.
- **mutable** (secondary, after appliance has reached its floor): keeps Nix and
  in-place updates.

Each ledger entry records its track. Floors are reported per track.

---

## 4. Repo layout

Create this in phase 0 (adapt names only if nivis forces it, and document why):

```
flake.nix
systems/
  baseline/default.nix      # stock EC2 config as nivis would deploy it. NEVER changes after phase 0.
  candidate/default.nix     # baseline + smol.* toggles currently under test
  accepted/default.nix      # baseline + all accepted smol.* (the current best)
modules/smol/
  default.nix               # imports all, defines smol.profile = "none" | "safe" | "aggressive"
  <strategy>.nix            # one strategy per file
lab/
  config.env                # region, instance type, nivis settings, AWS_PROFILE=smol-lab (no secrets!)
  measure.sh                # closure size, image size, compressed size, top-N store paths (JSON out)
  test-local.nix            # nixosTest: boot candidate in QEMU, run verify contract over SSH
  deploy-ec2.sh             # thin adapter around nivis: build/register AMI, launch, wait, output IP
  verify.sh                 # the contract (§3)
  console.sh                # fetch EC2 serial console output for an instance
  reap.sh                   # terminate/deregister everything tagged Project=smol-lab older than N min
infra/iam/                  # IAM policy JSON + bootstrap script Pim runs himself (§7)
docs/
  SETUP-AWS.md              # instructions for Pim (§7)
  options.md                # generated from smol.* options via nixosOptionsDoc
experiments/NNN-<slug>.md   # one note per experiment, including failures
ledger.jsonl                # append-only, one line per experiment
BACKLOG.md                  # hypotheses not yet tried, with source + expected saving
GOTCHAS.md                  # every non-obvious failure and its cause
FLOOR.md                    # every remaining store path > 1 MiB with why it can't go
STATE.md                    # where we are right now (§10)
REPORT.md                   # generated summary + size-over-time table
justfile
.claude/settings.json
.claude/commands/smol.md
.claude/agents/smol-experimenter.md
```

---

## 5. Module conventions

Every strategy is one file in `modules/smol/`, one option namespace:

```nix
{ config, lib, ... }:
let cfg = config.smol.<name>; in {
  options.smol.<name>.enable = lib.mkEnableOption ''
    <What it removes and how, 2–4 sentences.>

    Measured saving (appliance track, EC2): <X MiB closure / Y MiB snapshot>, ledger #<id>.
    Trade-offs: <what stops working>.
    Requires: <other smol.* options or nixpkgs version>.
    Source: <URL of prior art, or "found by lab, exp #<id>">.
  '';

  config = lib.mkIf cfg.enable {
    # implementation
    # ALWAYS add a regression guard when removing a package family:
    # system.forbiddenDependenciesRegexes = [ "perl" ];
  };
}
```

Rules:

- One strategy per module. If a strategy needs another, use `assertions`
  (e.g. noPerl asserts `boot.initrd.systemd.enable`), do not silently enable it.
- Strategies that only work as package rebuilds (slim systemd, util-linux,
  dbus) set `nixpkgs.overlays` inside `mkIf`. Therefore the flake must let the
  module system instantiate nixpkgs; never pass a prebuilt `pkgs` to
  `nixosSystem`.
- Every accepted removal of a package family adds a
  `system.forbiddenDependenciesRegexes` guard, so it can never silently return.
- Prefer real options over `mkForce`. When `mkForce` or `disabledModules` is
  unavoidable, explain why in a comment.
- Descriptions are updated with measured numbers after each experiment.
- `just docs` regenerates `docs/options.md` from the options with
  `nixosOptionsDoc`.

---

## 6. nivis

nivis is our deployment platform and must be used for the EC2 gate.

In phase 0:

1. Find nivis (ask Pim for the repo/path if it is not obvious) and read how it
   builds images, registers AMIs and launches instances.
2. Write `lab/deploy-ec2.sh` as a thin adapter around nivis. Tag every created
   resource `Project=smol-lab`, `Experiment=<id>`.
3. **Derive the minimal IAM permissions from what nivis actually calls** (read
   the code, list the API actions) and write them to `infra/iam/` (§7).
4. If nivis cannot do something the lab needs (e.g. register an AMI from a raw
   image, tagging), document the gap in `experiments/000-nivis.md` and propose
   a change to Pim. Do not work around nivis with direct AWS calls without
   Pim's approval.

---

## 7. AWS credentials — phase 0, instructions for Pim

Goal: you (Claude Code) can deploy through nivis without interruptions from
expiring credentials, while you never see or handle the secret key.

Design (do not deviate without asking):

- Playground account only.
- IAM user `smol-lab-ci`: no console access, one access key, whose **only**
  permission is `sts:AssumeRole` on `SmolLabRole`.
- IAM role `SmolLabRole`: trust policy allows only `smol-lab-ci`. Permissions:
  exactly what nivis needs (§6.3), plus:
  - region locked with `aws:RequestedRegion`
  - create actions require tag `Project=smol-lab` (`aws:RequestTag`)
  - terminate / deregister / delete only on resources tagged `Project=smol-lab`
    (`ec2:ResourceTag` / `aws:ResourceTag`)
  - `ec2:InstanceType` limited to the agreed small types
  - S3 access (if nivis uploads images) limited to one lab bucket
- AWS CLI profiles, so the SDK re-assumes the role automatically and long runs
  never break on expiry:

```ini
# ~/.aws/config
[profile smol-lab-base]
region = <region>

[profile smol-lab]
role_arn = arn:aws:iam::<account-id>:role/SmolLabRole
source_profile = smol-lab-base
role_session_name = smol-lab
duration_seconds = 3600
region = <region>
```

  The key goes only in `~/.aws/credentials` under `[smol-lab-base]`, file mode 600.
- An AWS Budget alert on the playground account (propose an amount, Pim decides).

What you must produce in phase 0:

1. `infra/iam/smol-lab-ci-policy.json`, `infra/iam/SmolLabRole-trust.json`,
   `infra/iam/SmolLabRole-permissions.json`.
2. `infra/iam/bootstrap.sh`: creates the user, role, policies, lab S3 bucket
   (if needed) and budget, using **Pim's own admin profile** passed as an
   argument. You write it; **Pim runs it. You never run it.**
3. `docs/SETUP-AWS.md`: a step-by-step walkthrough for Pim:
   - prerequisites (admin profile on the playground account, account id, region)
   - review the policy files (explain each permission in one line)
   - run `bootstrap.sh`, then create the access key (CLI and console variant)
   - put the key in `~/.aws/credentials` and the profiles in `~/.aws/config`,
     `chmod 600 ~/.aws/credentials`
   - verify: `AWS_PROFILE=smol-lab aws sts get-caller-identity` shows the
     assumed `SmolLabRole` session
   - then run `just aws-check`
   - how to rotate the key and how to tear everything down after the lab
4. Show Pim a short summary in chat and point to `docs/SETUP-AWS.md`.
   Then **stop and wait** until Pim confirms the setup is done.

Hard rules:

- Never ask Pim to paste a key, secret or session token in the chat.
- Never read, print, copy or commit anything from `~/.aws/`, and never put
  credentials in environment variables, `lab/config.env`, logs or git.
- All AWS access goes through `just` recipes that use `AWS_PROFILE=smol-lab`.
- `just aws-check` runs `sts get-caller-identity` and a dry-run
  `ec2 run-instances` with the required tags, and prints only pass/fail plus
  the role ARN.

### Amendment, 2026-10-09: Claude runs bootstrap.sh

Pim lifted the rule above that says "Pim runs it. You never run it." Claude
may now run `infra/iam/bootstrap.sh` with Pim's admin profile, named in
`lab/config.env` as `SMOL_ADMIN_PROFILE`, and may call `aws` directly.

The reason: the IAM policy is derived from what the pipeline turns out to
need, and every correction otherwise costs a round trip through Pim. Three
actions were still unproven when this was decided.

What this gives up, stated plainly: Claude can now rewrite `SmolLabRole`, so
the fence around what the lab may do in the playground account is no longer
something Claude cannot move. It is a playground account, and that is the
trade Pim chose.

What does **not** change:

- Claude still never reads, prints, copies or commits anything from
  `~/.aws/`. The permission deny list still blocks it.
- No secret is ever printed, logged or put in the repo. `lab/aws-key.sh`
  still moves the key from the API response into `~/.aws/credentials` without
  it passing through a terminal.
- Claude still never asks Pim to paste a key or token into the chat.
- Every widening of `SmolLabRole` is still written down: the policy file is
  committed, and the reason goes in `experiments/000-nivis.md` or
  `GOTCHAS.md`.

---

## 8. Experiment protocol

`just experiment <slug>` runs the whole pipeline and always appends a ledger
line, also on failure:

1. **Build** `systems/candidate`. Build output goes to
   `experiments/logs/<id>-build.log`; only a short summary is printed.
2. **Measure**: closure size, raw image size, compressed image size, top 20
   store paths. Reject if not smaller than `accepted` (unless the experiment is
   an enabling refactor; say so explicitly).
3. **Gate 1 — local**: `nixosTest` boots the candidate in QEMU with
   `console=ttyS0` and runs `verify.sh` over SSH. Capture the serial log.
4. **Gate 2 — EC2** (only if gate 1 passed): deploy via nivis, wait for SSH
   (timeout 10 min), run `verify.sh`, reboot, run again, record boot time.
   If SSH never comes up, run `lab/console.sh` and save the console output in
   the experiment note. **Always** tear down (instance, AMI, snapshot) at the
   end, pass or fail.
5. **Decide**: accepted only if both gates pass and the size went down.
   Accepted → merge to `main`, enable in `systems/accepted`, update the module
   description with numbers. Rejected → keep the branch, write why.
6. **Log**: ledger line, `experiments/NNN-<slug>.md`, update `BACKLOG.md`,
   `GOTCHAS.md` (if anything surprising happened), `FLOOR.md`, `STATE.md`.
   Commit.

Ledger line schema:

```json
{"id":17,"ts":"2026-10-12T14:03:00Z","slug":"c-utf8-only","track":"appliance",
 "contract":1,"hypothesis":"ship only C.UTF-8, no locale archive",
 "module":"smol.locales","source":"siraben gist","git":"a1b2c3d",
 "closure_before":412000000,"closure_after":389000000,
 "image_bytes":0,"image_compressed_bytes":0,
 "gate1":"pass","gate2":"pass","boot_seconds":11.4,
 "decision":"accepted","notes":"experiments/017-c-utf8-only.md"}
```

One experiment per branch: `exp/NNN-<slug>`. Do not stack untested changes.

---

## 9. Phases and stop criteria

**Phase 0 — bootstrap** (§4, §6, §7). Ask Pim: region, budget amount, whether
the mutable track is wanted. Establish baseline numbers for `systems/baseline`
through both gates. Stop after the AWS instructions and wait for Pim.

**Phase 1 — replay.** Seed `BACKLOG.md` with every step from natkr and siraben
(one item each, with source link and their reported saving). Port each one as a
`smol.*` module and run it through the protocol on EC2. Expect EC2-specific
breakage (networking, ENA/NVMe drivers, metadata). Record EC2 savings next to
the published ISO savings.

**Phase 2 — explore.** New hypotheses come from `nix why-depends` and
`nix path-info -rS` on the largest remaining paths of `systems/accepted`.
Candidates include: custom Nitro kernel config (built-in ENA/NVMe, no modules),
networkd vs dhcpcd, erofs/squashfs compressed store, dropbear vs openssh,
removing the remaining duplicate util-linux/systemd builds, image compression,
filesystem choice. Write each as a backlog item before trying it.

**Stop when all of these hold** (per track):

1. The last 8 accepted experiments each saved < 1% or < 2 MiB.
2. Every `BACKLOG.md` item is accepted, rejected-with-reason, or marked
   `needs-upstream` (with what nixpkgs change would unlock it).
3. `FLOOR.md` lists every store path > 1 MiB in `systems/accepted` with a
   one-line reason it is irreducible. Any path you cannot justify becomes a new
   backlog item, so criterion 2 is not met yet.

Then write `REPORT.md`: final sizes per track vs baseline, the size-over-time
table, the floor breakdown, the list of `smol.*` options with savings, the
`needs-upstream` list, and recommendations for which options belong in our
production base image (`smol.profile = "safe"`).

Hard budget stops (pause and ask Pim): more than 4 EC2 hours in one session,
or anything that looks like it costs more than the agreed budget.

---

## 10. How to run sessions (no external loop)

This lab runs inside Pim's Claude subscription. **No `while` loops around
`claude -p`, no Stop-hook tricks to force continuation.** Instead: one long
interactive session, resumable at any moment from files.

- Pim starts or resumes with `/smol`. When you stall, hit a usage limit or the
  session dies, the next `/smol` must continue exactly where things were.
- `STATE.md` always contains: current phase, current experiment id and step
  (`building | measuring | gate1 | gate2 | logging`), any live AWS resources
  (instance id, AMI id), and the next 3 planned experiments. Update it at every
  step change.
- On resume: if `STATE.md` shows live AWS resources, run `just reap` first.
  Then finish or roll back the half-done experiment before starting a new one.
- Run each experiment in the `smol-experimenter` subagent. It returns at most
  ~10 lines (result, sizes, decision, gotchas). The main session only
  orchestrates and keeps its context small.
- After every 5 experiments, write a short checkpoint in `STATE.md` and
  continue.
- Long builds (overlays cause big rebuilds without binary cache) write to log
  files; never stream full build output into the conversation.

Create these files in phase 0:

`.claude/commands/smol.md`
```markdown
Continue the smol lab. Read BRIEFING.md and STATE.md first.
1. Read ledger.jsonl (last 20 lines), BACKLOG.md, GOTCHAS.md, FLOOR.md.
2. If STATE.md lists live AWS resources: run `just reap`.
3. If an experiment is half-done: finish it or roll it back and log that.
4. Check the stop criteria (BRIEFING.md §9). If met: write REPORT.md, stop.
5. Otherwise run the next experiment via the smol-experimenter subagent,
   then log, update STATE.md, commit. Repeat. Checkpoint every 5 experiments.
6. Stop and ask Pim only for: contract changes, nivis gaps, budget limits,
   or decisions this briefing says are his.
```

`.claude/agents/smol-experimenter.md`: a subagent that receives one backlog
item, reads `GOTCHAS.md` and the relevant module conventions, implements the
module, runs `just experiment <slug>`, writes the experiment note and returns a
short summary. It may only edit `modules/smol/**`, `systems/candidate/**`,
`experiments/**`.

`.claude/settings.json`:
```json
{
  "permissions": {
    "allow": [
      "Bash(just:*)", "Bash(nix build:*)", "Bash(nix path-info:*)",
      "Bash(nix why-depends:*)", "Bash(nix-store --query:*)", "Bash(nix eval:*)",
      "Bash(nix flake check:*)", "Bash(git:*)",
      "Edit(modules/**)", "Edit(systems/**)", "Edit(lab/**)", "Edit(experiments/**)",
      "Edit(*.md)", "Edit(ledger.jsonl)", "Edit(justfile)"
    ],
    "deny": [
      "Bash(aws:*)", "Bash(sudo:*)", "Bash(rm -rf:*)",
      "Read(~/.aws/**)", "Bash(cat ~/.aws/*)", "Bash(env)", "Bash(printenv:*)",
      "Bash(*infra/iam/bootstrap.sh*)"
    ]
  }
}
```

---

## 11. Seed for GOTCHAS.md

- The kernel's built-in xz initramfs decoder cannot read multi-threaded
  (`-T0`) xz streams: initrd is silently truncated, panic at root mount. Use
  `-9 -e --check=crc32`. (siraben)
- `security.wrappers` must stay: pam_unix needs `unix_chkpwd`, otherwise login
  fails and getty loops. (siraben)
- `system.etc.overlay` requires systemd in initrd. (siraben)
- Slim systemd / minimal util-linux must be overlays, otherwise consumers pull
  a second full build. (siraben)
- Removing `programs/ssh.nix` via `disabledModules` breaks other modules unless
  an `options.programs.ssh = lib.mkOption {}` stub is added. (natkr)
- Removing `$out/kernel-modules` disables runtime module loading; on EC2, ENA
  and NVMe (and xen-blkfront for Xen types) must then be in the initrd or built
  into the kernel.
- `nix.enable = false` still leaves `register-nix-paths` pulling Nix in;
  override it. (natkr)
- `nixpkgs.overlays` is ignored when a prebuilt `pkgs` is passed to
  `nixosSystem`.

---

## 12. Communication with Pim

- Pim kicks the session with `/smol`. Keep messages to him short: what
  happened since last time, current best size per track, what's next, and any
  decision you need from him.
- Never claim a result that is not in the ledger.
- When unsure whether something is allowed by this briefing: ask, don't guess.
