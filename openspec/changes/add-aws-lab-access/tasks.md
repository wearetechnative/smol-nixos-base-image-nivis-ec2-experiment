## 1. Agree the parameters with Pim

- [ ] 1.1 Ask Pim for the AWS region and record it in `lab/config.env`
- [ ] 1.2 Propose a budget amount and get Pim's decision
- [ ] 1.3 Ask whether the mutable track is wanted, and record the answer in `STATE.md`
- [ ] 1.4 Agree the list of permitted instance types, starting from `t3.micro`
- [ ] 1.5 Decide gap 3: create the `vmimport` role once in `bootstrap.sh`, or let the lab create it per run and grant `SmolLabRole` the IAM writes
- [ ] 1.6 Decide gaps 1 and 2: whether `lab/console.sh` and the `lab/reap.sh` fallback may call `aws ec2` directly for read-only diagnostics and tag-filtered cleanup

## 2. Derive the permissions from nivis

- [x] 2.1 Read the nivis source and list the AWS API actions the deployment makes. They come from the OpenTofu AWS provider acting on the plan's resource types, not from nivis's own Go code
- [x] 2.2 Note which of those need an S3 bucket, and whether the lab therefore needs one. It does: the image goes through S3 to reach an EBS snapshot
- [x] 2.3 Write the resource-type-to-action mapping into `experiments/000-nivis.md`
- [x] 2.4 Verify the mapping covers teardown as well as creation, so `just reap` cannot be left unable to clean up
- [x] 2.5 Record the three gaps: no serial console, orphans after a crashed run, and the vmimport role's IAM cost
- [ ] 2.6 Confirm every `likely` action in the mapping with a dry run, and drop the ones the provider never calls

## 3. Write the IAM artifacts

- [ ] 3.1 `infra/iam/smol-lab-ci-policy.json`: `sts:AssumeRole` on `SmolLabRole` and nothing else
- [ ] 3.2 `infra/iam/SmolLabRole-trust.json`: trust only `smol-lab-ci`
- [ ] 3.3 `infra/iam/SmolLabRole-permissions.json`: the derived actions, with the region, tag and instance-type conditions
- [ ] 3.6 Exempt `aws_s3_object` and the policy attachment from the tag conditions; neither is taggable
- [ ] 3.4 Confirm each condition with a one-line explanation in a comment block in `docs/SETUP-AWS.md`
- [ ] 3.5 Verify the policies parse: `aws iam simulate-custom-policy` is not available to Claude, so validate the JSON shape only and have Pim confirm on apply

## 4. Write what Pim runs

- [ ] 4.1 `infra/iam/bootstrap.sh`, taking an admin profile as its argument, creating the user, role, policies, bucket if needed, and budget
- [ ] 4.2 Make the script idempotent, so a second run is safe
- [ ] 4.3 `docs/SETUP-AWS.md`: prerequisites, policy review, running bootstrap, creating the access key in CLI and console form, placing the key and profiles, `chmod 600`, verification, rotation, teardown
- [ ] 4.4 Confirm the repository's permission deny list blocks Claude from running `bootstrap.sh`

## 5. Make access verifiable

- [ ] 5.1 `lab/aws-check.sh`: `sts get-caller-identity` plus a dry-run tagged `ec2 run-instances`
- [ ] 5.2 Print only pass or fail and the role ARN; never print credentials or raw API output
- [ ] 5.3 Fail with a message naming the missing setup step when the profiles are absent
- [ ] 5.4 Wire it to `just aws-check` and add it to `nix flake check`'s shellcheck

## 6. Hand over and wait

- [ ] 6.1 Show Pim a short summary in chat and point at `docs/SETUP-AWS.md`
- [ ] 6.2 Stop and wait until Pim confirms the setup is done
- [ ] 6.3 After Pim confirms, run `just aws-check` and record the result in `STATE.md`
