# ec2-gate Specification

## Purpose

Deploying a candidate image to real EC2 through nivis, verifying it there
against the same contract the local gate runs, and guaranteeing that nothing
is left running afterwards. This is the only gate that can prove the Nitro
drivers, the metadata key injection and the real boot path still work after a
size reduction.

## Requirements

### Requirement: Deployment goes through nivis

The EC2 pipeline SHALL be expressed as nivis resources. Direct AWS calls are
permitted only where no provider resource exists, and only for read-only
diagnostics or tag-filtered cleanup.

#### Scenario: a candidate is deployed

- **WHEN** gate 2 runs for an experiment
- **THEN** the image build, upload, snapshot import, AMI registration and
  instance launch all happen through `nivis apply` against the flake's
  `nivis.plan` output

#### Scenario: a capability has no provider resource

- **WHEN** the lab needs serial console output, or needs to clean up a
  resource nivis holds no state for
- **THEN** it may call `aws ec2` directly, and the gap is recorded in
  `experiments/000-nivis.md` with a proposal rather than treated as normal

### Requirement: The SSH key is injected, never baked in

The key used to verify a candidate SHALL reach the instance through EC2
instance metadata, so that contract check 1 tests the real mechanism.

#### Scenario: a run starts

- **WHEN** gate 2 begins
- **THEN** it generates a fresh keypair into a temporary directory, registers
  the public half as an `aws_key_pair`, and launches the instance with that
  `key_name`

#### Scenario: a run ends

- **WHEN** gate 2 exits, for any reason
- **THEN** the private key is deleted, and no key material has been written
  into the repository or reused from a previous experiment

### Requirement: Both gates run the same contract

Gate 2 SHALL execute `lab/verify.sh`, unmodified, so that a local pass and an
EC2 pass mean the same thing.

#### Scenario: the contract runs on EC2

- **WHEN** the instance answers SSH
- **THEN** the harness pushes a statically linked curl to the target and runs
  `lab/verify.sh` over SSH with `VERIFY_ENV=ec2`, so the metadata-key check
  that gate 1 skips is exercised

#### Scenario: the instance is rebooted

- **WHEN** the contract has passed once
- **THEN** the instance is rebooted and the contract is run again, and both
  runs must pass for the gate to pass

### Requirement: Every created resource is tagged

Every resource the lab creates SHALL carry `Project=smol-lab` and
`Experiment=<id>`, because the IAM policy's create and delete conditions key
on them.

#### Scenario: a resource is created

- **WHEN** nivis applies the plan
- **THEN** the provider's `default_tags` apply both tags to every taggable
  resource, and the launch is permitted by the role

#### Scenario: a resource type cannot be tagged

- **WHEN** the plan includes a resource AWS does not support tags on
- **THEN** the IAM policy does not require a tag on it, so the pipeline is not
  blocked

### Requirement: Teardown is unconditional

Nothing the lab creates SHALL outlive the run that created it, whatever the
outcome.

#### Scenario: the gate passes

- **WHEN** both contract runs pass
- **THEN** the instance, AMI, snapshot, key pair, security group and uploaded
  image are destroyed before the script exits

#### Scenario: the gate fails or is interrupted

- **WHEN** the contract fails, SSH never comes up, or the operator interrupts
  the run
- **THEN** teardown still runs, and the script reports what it removed

#### Scenario: a previous run left something behind

- **WHEN** `just reap` runs
- **THEN** it destroys every stack the lab holds state for, then sweeps for
  resources tagged `Project=smol-lab` older than the configured age that no
  state file accounts for

### Requirement: A failed boot is diagnosable

An instance that never answers SSH SHALL still produce evidence.

#### Scenario: SSH does not come up within the timeout

- **WHEN** the instance has not accepted an SSH connection within ten minutes
- **THEN** the harness fetches the serial console output and writes it into
  the experiment note before tearing down

### Requirement: The run reports what a ledger line needs

Gate 2 SHALL produce the fields `ledger.jsonl` records, so no number in the
ledger is ever estimated.

#### Scenario: a gate 2 run finishes

- **WHEN** the run ends, pass or fail
- **THEN** it reports the gate result, the boot time measured on the guest,
  and the instance and AMI ids that existed during the run
