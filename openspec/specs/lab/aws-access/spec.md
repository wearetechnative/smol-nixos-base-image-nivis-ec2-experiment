# lab/aws-access Specification

## Purpose

Defines how the lab authenticates to AWS, what the lab is permitted to do
there, and where the line runs between artifacts Claude writes and actions
only Pim performs. The point is that an autonomous session can deploy to EC2
for hours without a human, while no secret ever passes through the agent.

## Requirements

### Requirement: Claude never handles a secret

No part of the lab may read, print, copy or commit credential material, and
no workflow may ask a human to paste one into a conversation.

#### Scenario: the agent is asked for a key

- **WHEN** any instruction would have Claude read `~/.aws/credentials`, echo a
  secret key, or request one in chat
- **THEN** the instruction is refused and the operator is pointed at
  `docs/SETUP-AWS.md` instead

#### Scenario: the bootstrap script is run

- **WHEN** `infra/iam/bootstrap.sh` is executed
- **THEN** it is executed by Pim with his own admin profile, never by Claude,
  and the repository's permission deny list blocks Claude from invoking it

### Requirement: Credentials outlive a long session

The lab must be able to run for hours without an expiring token interrupting
it.

#### Scenario: a session runs past the session token lifetime

- **WHEN** a gate 2 deployment starts after the previous role session expired
- **THEN** the SDK re-assumes `SmolLabRole` through the configured
  `source_profile` and the deployment proceeds without human intervention

### Requirement: The role is fenced to the lab

The role must not be able to touch anything outside the lab, even by mistake.

#### Scenario: a request targets another region

- **WHEN** an API call is made outside the region recorded in `lab/config.env`
- **THEN** the call is denied by the `aws:RequestedRegion` condition

#### Scenario: a resource is created without the project tag

- **WHEN** a create call omits `Project=smol-lab`
- **THEN** the call is denied by the `aws:RequestTag` condition

#### Scenario: a destructive call targets an untagged resource

- **WHEN** a terminate, deregister or delete call targets a resource that is
  not tagged `Project=smol-lab`
- **THEN** the call is denied by the `ec2:ResourceTag` or `aws:ResourceTag`
  condition

#### Scenario: an oversized instance type is requested

- **WHEN** a launch requests an instance type outside the agreed small types
- **THEN** the call is denied by the `ec2:InstanceType` condition

### Requirement: Permissions are derived, not guessed

The role's permissions must match what nivis actually calls.

#### Scenario: the permissions policy is written

- **WHEN** `infra/iam/SmolLabRole-permissions.json` is authored
- **THEN** every action in it is traceable to a call site in the nivis source,
  and no wildcard action is used where the call sites are known

### Requirement: Access is verifiable in one command

An operator must be able to tell whether AWS access works without reading
policy JSON.

#### Scenario: the operator runs the check

- **WHEN** `just aws-check` is run
- **THEN** it reports the assumed role ARN and a pass or fail for a dry-run
  tagged `ec2:RunInstances`, and prints nothing else

#### Scenario: the setup is incomplete

- **WHEN** `just aws-check` is run before Pim has finished `docs/SETUP-AWS.md`
- **THEN** it fails with a message naming the step that is missing
