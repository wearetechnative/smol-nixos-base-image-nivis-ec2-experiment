## 1. The nivis plan

- [x] 1.1 `lab/nivis-plan.nix`: the pipeline as nivis resources, taking the flake's nixosConfigurations and `ledger.vars`
- [x] 1.2 `mkVars` for `variant`, `experiment`, `region`, `instanceType` and `sshPublicKey`; only `region` and `instanceType` get defaults, from `lab/config.env`
- [x] 1.3 `default_tags = [ { tags = { Project = "smol-lab"; Experiment = <id>; }; } ]` on the provider, as a list-nested block
- [x] 1.4 `aws_key_pair` from `sshPublicKey`, and `key_name` on the instance
- [x] 1.5 Security group with ingress on 22 and egress to anywhere, not port 80
- [x] 1.6 `aws_s3_object` into the pre-created lab bucket; no `aws_s3_bucket` resource
- [x] 1.7 `aws_ebs_snapshot_import` with `role_name = "vmimport"`, the role the bootstrap created; no IAM resources in the plan
- [x] 1.8 `aws_ami` with `ena_support`, pointed at the snapshot
- [x] 1.9 Declared outputs for `public_ip`, `instance_id` and `ami_id`, so `nivis output --json` gives the harness what it needs
- [x] 1.10 Expose it as the flake's `nivis.plan`, and verify `nivis plan` evaluates without touching AWS

## 2. The ephemeral keypair

- [x] 2.1 Generate an ed25519 keypair into a temp dir created with `mktemp -d`, mode 700
- [x] 2.2 Delete the temp dir on every exit path, in the same trap as teardown
- [x] 2.3 Pass only the public half into nivis, as a `--var`
- [x] 2.4 Confirm no key material can reach the repository or the nix store

## 3. lab/deploy-ec2.sh

- [x] 3.1 Read `lab/config.env` through `lab/aws-env.sh`, and refuse to run if `just aws-check` would fail
- [x] 3.2 One state file per experiment under `experiments/state/`, passed with `--state`, so runs cannot collide
- [x] 3.3 `nivis apply`, with the narrative going to `experiments/logs/<id>-deploy.log` and only a summary printed
- [x] 3.4 Read `public_ip` and the ids from `nivis output --json`
- [x] 3.5 Wait for SSH with a ten minute timeout, polling rather than sleeping blind
- [x] 3.6 Push the static curl to `/tmp/smol-curl` on the target, as gate 1 does
- [x] 3.7 Run `lab/verify.sh` with `VERIFY_ENV=ec2`, so the metadata-key check runs
- [x] 3.8 Reboot, wait for SSH again, run the contract again; both must pass
- [x] 3.9 Measure boot time on the guest with `systemd-analyze`, not from the API
- [x] 3.10 Teardown in a trap covering success, failure and interrupt
- [x] 3.11 Print a short machine-readable summary the ledger can consume

## 4. Diagnostics and cleanup

- [x] 4.1 `lab/console.sh <instance-id>`: fetch serial console output, write it to a file, print only where it went
- [x] 4.2 Call it automatically when the SSH wait times out, before teardown
- [x] 4.3 `lab/reap.sh`: `nivis destroy` for every state file under `experiments/state/`
- [x] 4.4 Then sweep for instances, AMIs, snapshots, key pairs and security groups tagged `Project=smol-lab` older than `SMOL_REAP_AFTER_MINUTES` with no state file
- [x] 4.5 Make `reap` safe to run when there is nothing to do, and say so rather than failing
- [x] 4.6 Wire `just gate2`, `just console` and `just reap`

## 5. First real run

- [x] 5.1 Deploy `systems/baseline` end to end and watch where it breaks
- [x] 5.0 Add `just aws-probe`: dry-run authorisation for `RegisterImage` and `RunInstances`, plus a real create and destroy of the key pair and the security group, so an IAM gap costs seconds rather than a 2.6 GiB upload
- [x] 5.2 Confirm or correct the eleven `likely` IAM actions in `experiments/000-nivis.md`; update the policy and have Pim re-run `bootstrap.sh` if needed
- [x] 5.3 Confirm contract check 1 passes on EC2, which it cannot do locally
- [x] 5.4 Prove teardown on a failing run, then confirm the account is empty. The first attempt failed on `ec2:CreateSecurityGroup` and the trap destroyed the key pair and the uploaded image unprompted
- [x] 5.5 Record the baseline numbers and write ledger line 1
- [x] 5.6 Record the wall-clock cost of one gate 2 run in `STATE.md`, so the budget stop in BRIEFING §9 has a real number behind it

## 6. Bookkeeping

- [x] 6.1 Update `experiments/000-nivis.md` with what the real run taught
- [x] 6.2 Append anything surprising to `GOTCHAS.md`
- [x] 6.3 Update `docs/TESTING.md` with the gate 2 section as built
- [x] 6.4 Update `STATE.md`, then archive and commit
