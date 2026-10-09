# FLOOR

Every store path larger than 1 MiB in `systems/accepted`, with a one-line
reason it cannot be removed (BRIEFING §9.3).

A path listed here without a convincing reason is not a floor entry, it is a
`BACKLOG.md` item. Stop criterion 2 is not met while any such path exists.

Regenerate the raw list with:

```sh
just measure accepted | jq -r '.top_paths[] | "\(.bytes)\t\(.path)"'
```

## Appliance track

| path | bytes | why it stays |
| ---- | ----- | ------------ |
| _not measured yet_ | | |

## Mutable track

| path | bytes | why it stays |
| ---- | ----- | ------------ |
| _not measured yet_ | | |
