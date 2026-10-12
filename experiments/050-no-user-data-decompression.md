# 050 and 051: no-user-data-decompression

Rejected at #50 on a mistake of mine, accepted unchanged in substance at #51.

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noUserDataDecompression`
- **Source:** found by lab, exp #50, after #49 showed `file` had a second holder

## Hypothesis

`fetch-ec2-metadata.service` carries `file`, `bzip2`, `gzip`, `lzip`, `xz`
and `zstd` on its PATH for one reason: after downloading user-data it runs
`file --brief` on it and pipes it through whichever decompressor matches.
`file-5.48` alone is 10.54 MiB of libmagic.

Nothing on this image reads user-data. `smol.noAmazonInit` removed the
service that did, in experiment 4. The fetched file has had no reader for
forty-six experiments.

## What changed

[`modules/smol/no-user-data-decompression.nix`](../modules/smol/no-user-data-decompression.nix)
patches the call out of the upstream script rather than removing the tools
underneath it:

```nix
substitute ${pkgs.path}/nixos/modules/virtualisation/ec2-metadata-fetcher.sh $out \
  --replace-fail ' && try_decompress "$metaDir/user-data"' ""
```

Dropping the tools and leaving the call would pass every test here, because
the lab passes no user-data, and fail on the first instance that does.

## Numbers

| measure    | before | after  | delta        |
| ---------- | ------ | ------ | ------------ |
| closure    | 344.90 | 333.50 | 11.40, 3.3%  |
| image, raw | 478.12 | 470.12 | 8.00, 1.7%   |

These are MiB, bytes divided by 1048576, which is what `lab/experiment.sh`
prints. Several earlier notes and `FLOOR.md` divided by 1000000 and called
the result MiB; `FLOOR.md` is corrected in this commit.

Paths that moved: `file-5.48` (10.54) and `lzip`. `bzip2`, `gzip`, `xz`
and `zstd` all stay; each has another holder, systemd among them.

## Gate 1, local

Pass, 10 of 10, on both runs.

## Gate 2, EC2

**#50 failed.** No SSH in 600s. The serial console:

```
fetch-ec2-metadata-start: line 5: mkdir: command not found
[FAILED] Failed to start fetch-ec2-metadata.service.
```

The module set `path = lib.mkForce [ pkgs.curl ]`. `nixos/lib/systemd-lib.nix`
adds `coreutils`, `findutils`, `gnugrep`, `gnused` and `systemd` to every
stage-2 service with `mkAfter`, and `mkForce` discards that definition along
with the module's own. The service had `curl` and nothing else.

Gate 1 did not catch it because the NixOS test driver's nodes are built
differently enough that the unit still found its tools there, which is the
second time the two gates have disagreed about a PATH.

**#51 passed** with that list restated in the module. Boot 13.11s.

Teardown: both instances, AMIs and snapshots destroyed; `STATE.md` live
table empty.

## Decision

Accepted at #51. 11.41 MiB closure, 8.00 MiB image. This is the second
holder `FLOOR.md` did not record and the reason experiment 49 bought so
little.

## Surprises

`mkForce` on `systemd.services.<name>.path` is not "replace what this
module set". It replaces the default service path too, and the failure is
invisible until a service that uses `mkdir` runs on a real boot. Copied to
`GOTCHAS.md`.
