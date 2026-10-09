# infra/iam/

Written by Claude, run by Pim. Nothing in this directory is ever executed by
the agent; `.claude/settings.json` denies it.

| file | what it is |
| ------------------------------- | ---------------------------------------- |
| `smol-lab-ci-policy.json`       | the IAM user's only permission: assume `SmolLabRole` |
| `SmolLabRole-trust.json`        | who may assume the role: only `smol-lab-ci` |
| `SmolLabRole-permissions.json`  | what the role may do, derived from what nivis calls |
| `bootstrap.sh`                  | creates the user, role, policies, bucket and budget |

The permissions are derived from the call sites recorded in
`experiments/000-nivis.md`. No action belongs in the policy without a row in
that table.

Walkthrough for Pim: `docs/SETUP-AWS.md`.
