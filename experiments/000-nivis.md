# 000: nivis

Not an experiment. This note records what nivis can and cannot do for the lab,
and it is the input for the IAM permissions (BRIEFING §6.3 and §7).

nivis: <https://github.com/nivis-project/nivis>, local checkout at
`~/gh.nivis-project/nivis`. OpenTofu provider resources as first-class Nix
values, applied by a Go executor that speaks the provider plugin protocol
directly to unmodified provider binaries.

Sources read: `nix/example/ec2.nix`, `docs/TUTORIAL-EC2-NIXOS.md`,
`docs/VARIABLES.md`, `nix/example/aws.nix`, `cmd/nivis/main.go`.

## The pipeline nivis already has

`nix/example/ec2.nix` is the whole thing, and it is the shape
`lab/deploy-ec2.sh` wraps. Nine resources across four phases:

```
aws_iam_role + aws_iam_policy + attachment   the vmimport service role
aws_s3_bucket + aws_s3_object                the built .vhd uploaded to S3
aws_ebs_snapshot_import                      S3 .vhd -> EBS snapshot
aws_ami                                      register the snapshot as an AMI
aws_security_group                           ingress
aws_instance                                 launch the AMI
```

The image is a `drv` leaf, so `nivis apply` builds the NixOS image itself
before uploading. No separate `nix build` step, and it works on a machine
where the image was never built.

## What the lab needs from it

| need | status | note |
| ---- | ------ | ---- |
| build a NixOS image for EC2 | yes | `config.system.build.images.amazon` as a `drv` leaf, realised inside `nivis apply` |
| register an AMI from that image | yes | `aws_ebs_snapshot_import` then `aws_ami` |
| launch an instance of a given type | yes | `aws_instance`, type through `mkVars` |
| tag every created resource | yes | `default_tags` on the provider, a list-nested block: `default_tags = [ { tags = { ... }; } ]` |
| region from `lab/config.env` | yes | `mkVars` with a `region` variable, set per run |
| return the instance's public IP | yes | `nivis state show aws.aws_instance.web` reads `public_ip` back out of state |
| terminate, deregister, delete the snapshot | yes | `nivis destroy`, reverse dependency order |
| SSH into the instance | **no, needs adding** | the example only opens port 80 and has no key pair |
| fetch serial console output | **no** | see gap 1 |
| clean up orphans from a crashed run | **partly** | see gap 2 |

## What `lab/deploy-ec2.sh` must add to the example

The example serves HTTP on port 80 and never logs in. The contract needs SSH
with a key injected from instance metadata, so the plan gains:

1. `aws_key_pair`, and `key_name` on the `aws_instance`. This is what makes
   contract check 1 real: the key reaches the instance through IMDS, not baked
   into the image.
2. Security group ingress on 22 rather than 80.
3. `default_tags = [ { tags = { Project = "smol-lab"; Experiment = "<id>"; }; } ]`
   on the provider, so every taggable resource carries the tags the IAM policy
   conditions require. `aws_s3_object` and the policy attachment are not
   taggable; the conditions must not require tags on those.
4. `mkVars` for `region`, `instanceType`, `experimentId` and `suffix`, fed from
   `lab/config.env`.

## AWS API actions

The actions come from the **OpenTofu AWS provider acting on these resource
types**, not from nivis's own Go code. nivis speaks the plugin protocol; the
provider binary makes the calls. So the policy is derived per resource type.

Confidence column: `certain` means the action is named in the resource's
documented behaviour or in the vmimport policy the example itself writes;
`likely` means the provider reads it during plan or refresh and a dry run
should confirm it. Nothing goes into
`infra/iam/SmolLabRole-permissions.json` without a dry-run confirmation.

| resource | actions | confidence |
| -------- | ------- | ---------- |
| `aws_key_pair` | `ec2:ImportKeyPair`, `ec2:DescribeKeyPairs`, `ec2:DeleteKeyPair`, `ec2:CreateTags` | certain |
| `aws_s3_bucket` | `s3:CreateBucket`, `s3:DeleteBucket`, `s3:ListBucket`, `s3:GetBucketLocation`, `s3:PutBucketTagging`, `s3:GetBucketTagging` | certain |
| `aws_s3_bucket` (refresh) | the provider's `s3:GetBucket*` reads: acl, policy, versioning, logging, lifecycle, cors, website, replication, encryption, accelerate, request-payment, object-lock | likely |
| `aws_s3_object` | `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject`, `s3:GetObjectTagging` | certain |
| `aws_ebs_snapshot_import` | `ec2:ImportSnapshot`, `ec2:DescribeImportSnapshotTasks`, `ec2:DescribeSnapshots`, `ec2:DeleteSnapshot`, `ec2:CreateTags` | certain |
| `aws_ebs_snapshot_import` | `ec2:ModifySnapshotAttribute`, `ec2:CopySnapshot` | likely, the vmimport policy grants them to the service role |
| `aws_ami` | `ec2:RegisterImage`, `ec2:DeregisterImage`, `ec2:DescribeImages`, `ec2:DescribeImageAttribute`, `ec2:CreateTags` | certain |
| `aws_security_group` | `ec2:CreateSecurityGroup`, `ec2:DeleteSecurityGroup`, `ec2:DescribeSecurityGroups`, `ec2:AuthorizeSecurityGroupIngress`, `ec2:AuthorizeSecurityGroupEgress`, `ec2:RevokeSecurityGroupIngress`, `ec2:RevokeSecurityGroupEgress`, `ec2:CreateTags` | certain |
| `aws_security_group` | `ec2:DescribeVpcs` | likely |
| `aws_instance` | `ec2:RunInstances`, `ec2:TerminateInstances`, `ec2:DescribeInstances`, `ec2:CreateTags` | certain |
| `aws_instance` (refresh) | `ec2:DescribeInstanceAttribute`, `ec2:DescribeInstanceTypes`, `ec2:DescribeInstanceCreditSpecifications`, `ec2:DescribeVolumes`, `ec2:DescribeSubnets`, `ec2:DescribeNetworkInterfaces` | likely |
| `aws_iam_role` + `aws_iam_policy` + attachment | `iam:CreateRole`, `iam:GetRole`, `iam:DeleteRole`, `iam:TagRole`, `iam:CreatePolicy`, `iam:GetPolicy`, `iam:GetPolicyVersion`, `iam:ListPolicyVersions`, `iam:DeletePolicy`, `iam:AttachRolePolicy`, `iam:DetachRolePolicy`, `iam:ListAttachedRolePolicies` | certain, **but see gap 3** |
| `lab/console.sh` | `ec2:GetConsoleOutput` | certain, **see gap 1** |
| `lab/aws-check.sh` | `sts:GetCallerIdentity`, `ec2:RunInstances` with `DryRun` | certain |

## Gaps

### Gap 1: no serial console output

`lab/console.sh` is the only thing that tells us why an instance never came up,
and the briefing requires it when SSH does not appear within ten minutes.
`ec2:GetConsoleOutput` is an API action with no corresponding provider
resource, so nivis cannot express it.

**Proposal for Pim:** allow `lab/console.sh` to call
`aws ec2 get-console-output` directly. It is read-only diagnostics on an
instance the lab already created, not a deployment path, so it does not
undermine "deploy through nivis". The alternative is flying blind on every
failed boot.

### Gap 2: orphans from a crashed run

`nivis destroy` works from its own state file. If a session dies before the
state is written, or the state is lost, the resources exist and nivis does not
know about them. `just reap` is the backstop the briefing asks for:
terminate and deregister everything tagged `Project=smol-lab` older than N
minutes.

**Proposal for Pim:** `lab/reap.sh` tries `nivis destroy` first, and falls
back to tag-and-age-based `aws ec2` calls only for what nivis has no state
for. The same reasoning as gap 1: cleanup of resources the lab created,
guarded by a tag filter, not a deployment path. Leaving orphaned instances
running is the worse outcome.

### Gap 3: the vmimport role costs the lab every IAM write permission

AWS requires a `vmimport` service role for disk-image import. The example
creates it per deployment, which means `SmolLabRole` would need
`iam:CreateRole`, `iam:CreatePolicy`, `iam:AttachRolePolicy` and their delete
counterparts. That is a large privilege to hand an autonomous agent, and it
sits badly with BRIEFING §7's "exactly what nivis needs".

The nivis tutorial itself offers the way out: "If your account already has a
`vmimport` role, point `aws_ebs_snapshot_import.role_name` at it instead."

**Proposal for Pim:** `infra/iam/bootstrap.sh` creates `vmimport` once, with
Pim's admin profile, scoped to the single lab bucket. The lab plan references
it by name. `SmolLabRole` then needs no IAM write permission at all. The cost
is one more thing in the bootstrap; the gain is that the agent's role cannot
create or modify IAM.

This is not a nivis gap, it is a choice about where the role is created, so it
needs no change to nivis.

## Other findings

- **Every experiment uploads the image to S3.** The example uploads roughly
  2 GB. Reuse one lab bucket keyed by experiment id rather than a bucket per
  run, and keep `force_destroy = true`. Upload time will shrink along with the
  image, which is the point of the lab.
- **The state lock is held for the whole run, build included.** A long image
  build blocks other runs against the same state. One experiment at a time is
  the briefing's rule anyway.
- **The snapshot import takes a few minutes**, which is AWS, not nivis. The
  gate 2 timeout must account for it separately from the ten minute SSH wait.
- **Boot time** for the ledger is better measured on the guest with
  `systemd-analyze` than from the API, which only knows when the launch call
  returned.
