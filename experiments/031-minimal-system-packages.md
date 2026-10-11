# 027 to 031: minimal-system-packages

Five ledger lines, one result. Accepted at #31.

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.minimalSystemPackages`
- **Source:** natkr, backlog item `n5`

## Hypothesis

A stock EC2 NixOS has 57 packages on the system path. Among them: `man-db`,
`bind`, `nano`, `less`, `shared-mime-info`, `hicolor-icon-theme`,
`sound-theme-freedesktop`, `fontconfig`, `cryptsetup`, `lvm2`,
`bcache-tools`, `dosfstools`, `kexec-tools`, `mkpasswd`, `patch`, and GRUB's
install tools. None has a caller on a headless machine that is replaced
rather than reconfigured.

This was also expected to close backlog item `e11`: `grub-2.14` is in the
closure because `boot/loader/grub/grub.nix` does
`environment.systemPackages = mkIf (grub != null) [ grub ]`, so the running
system can reinstall its own bootloader.

**It did not.** See the correction at the end of this note.

## What changed

`environment.systemPackages` replaced with an explicit list of 16, plus an
escape hatch:

```nix
options.smol.minimalSystemPackages.extra = ... # for things that must come back
config.environment.systemPackages = lib.mkForce (cfg.extra ++ [ ... ]);
```

`mkForce` on the whole list is what BRIEFING §5 asks to avoid. The reason it
is unavoidable here: the contributions come from a dozen modules with no
common switch, and filtering the existing list in place reads
`config.environment.systemPackages` from inside its own definition, which
makes the module system recurse. The explicit list is also the more honest
form, because it states what the appliance needs rather than what nobody got
around to removing.

## Numbers

| measure           | before      | after       | delta         |
| ----------------- | ----------- | ----------- | ------------- |
| closure           | 640 251 936 | 579 854 408 | 60 397 528    |
| closure, MiB      | 610.59      | 553.27      | 57.32, 9.4%   |
| image, raw VHD    | 799 214 592 | 709 014 528 | 90 200 064    |
| image, MiB        | 762.19      | 676.16      | 86.03, 11.3%  |

## The four rejections before it

| # | caught by | what it was |
| - | --------- | ----------- |
| 27 | gate 1 | `nc: command not found`. The **test driver** needs netcat for `wait_for_open_port`; the appliance does not. Fixed with the `extra` seam, used from `lab/test-support/qemu.nix`. |
| 28 | gate 1 | contract check 4 failed while check 5 passed |
| 29 | gate 1 | same, after a wrong fix |
| 30 | gate 2 | `no curl at $VERIFY_CURL` |

**Experiments 28 and 29 are the interesting pair.** DNS resolution failed for
`getent` and succeeded for `curl`, against the same host. That looks
contradictory until you notice the harness pushes a *static musl* curl, which
resolves names itself and never touches NSS. Only check 4 was telling the
truth. The cause was `getent`: it is a separate wrapper derivation in
nixpkgs, not an output of glibc, so `pkgs.glibc` does not provide it.

My first diagnosis was `openresolv`, which was wrong, and experiment 29 is
the ledger line for being wrong. The right method was comparing
`config.system.path` between the accepted and candidate systems and finding
`bin/getent` missing, which took one command and no deployment.

**Experiment 30 was not the candidate's fault at all.** `static-curl` is
multi-output, so `nix build --print-out-paths` printed two store paths and
`lab/deploy-ec2.sh` built a nonsense argument from them. The bug had been
latent since gate 2 was written and only surfaced when the `man` output
happened to get built. The contract then reported "no HTTPS client", which
was a lie about the candidate. `deploy-ec2.sh` now picks the output holding
the binary, and fails loudly if the push fails rather than letting the
contract report a missing client.

## Gate 1, local

Pass at #31. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass at #31. Boot time **13.634s**. Teardown: all six resources destroyed.

## Decision

**Accepted.** Profile: `aggressive` only. Losing `man`, an editor and the
LVM and LUKS tooling is fine on an appliance and not fine on a base image
somebody is expected to debug by hand.

## Surprises

Three of the four rejections were defects in the lab, not in the candidate:
one in gate 1's environment, one in my diagnosis, one latent in gate 2 since
it was written. Only experiment 28's underlying cause was a real property of
the change.

That ratio is worth watching. A protocol that reports "rejected" for its own
bugs still works, because the notes say which was which, but it means the
rejection count in the README is not a measure of how wrong the hypotheses
were.


## Correction, after experiment 36

This note originally said experiment 31 closed backlog item `e11` by
removing GRUB from the closure. That is wrong, and listing the top paths
after experiment 36 is what showed it: `grub-2.14` is still there at 36.30
MiB.

GRUB had two holders. The system path was one, and this experiment removed
it. The other is `switch-to-configuration`:

```
nixos-system
└── bin/switch-to-configuration: INSTALL_BOOTLOADER='.../install-grub.sh'
    └── install-grub.pl .../grub-config.xml
        └── <string value=".../grub-2.14/share/grub/unicode.pf2"/>
```

`switch-to-configuration` cannot be removed: experiment 21 established that
the amazon image builder calls it, and that is the lab's `needs-upstream`
item. So `e11` is blocked behind `s6` and is not closed.

The irony is not lost: this note's own "Surprises" section describes the
multiple-holder trap, and the claim was written without re-checking the
closure afterwards. The rule from experiment 9 is **run `why-depends` again
on the result**, and I did not. `BACKLOG.md` now says `explained, not
removed`.
