# AWS User Key Management

Bash tool for rotating IAM access keys of many service users in one run.
Users are read from a list file in `info/`; each action asks for confirmation
before changing anything.

## Requirements

- bash, [AWS CLI](https://aws.amazon.com/cli/) v2, [jq](https://jqlang.github.io/jq/)
- AWS CLI profiles named in the info files (e.g. `ARacconut1Admin`, `ARacconut2Admin`)
  with permission to run `iam:ListAccessKeys`, `iam:GetAccessKeyLastUsed`,
  `iam:CreateAccessKey`, `iam:UpdateAccessKey` and `iam:DeleteAccessKey`
  on the target users.

## Usage

The script finds its own `layer-*.sh` files and `tmp/` folder, so it can be started from any directory (the `<info-file>` path is relative to where you start it, or absolute):

```bash
./main-bulk-rotate-iam-keys.sh <info-file> <action>
```

| Action       | What it does |
|--------------|--------------|
| `list`       | Shows each user's keys, status, create date and last-used info. |
| `inactivate` | If the user has 2 active keys, asks, then inactivates the oldest. |
| `delete`     | If the user has an inactive key, shows the oldest one, asks, then deletes only that key (another inactive key is kept). |
| `create`     | If the user has exactly 1 key, asks, then creates a second key and prints it. |

Example:

```bash
./main-bulk-rotate-iam-keys.sh info/test_ALL.txt list
```

### Rotation order

1. `create`      – add the new key (a user can have at most 2 keys)
2. update the consuming application with the new key
3. `inactivate` – deactivate the old key
4. verify nothing broke (`list` shows last-used date)
5. `delete`     – remove the oldest inactive key

## Info file format

One user per line: `<iam_username>|<aws_cli_profile>`.
Lines starting with `#` are skipped. Keep the final `# -- END …` line.

```
# -- CURRENT TEST
s-test-app-backup|ARacconut1Admin
s-test-app-reports|ARacconut1Admin
# -- END (INDICATES THAT NO MORE LINES IN THIS FILE. KEEP THIS LINE HERE)
```

Sample lists in `info/` (all names are fake): `*_users.txt` use profile
`ARacconut1Admin`; `*_users_dev.txt` use `-dev` usernames and `ARacconut2Admin`.

## Layout

| Path | Purpose |
|------|---------|
| `main-bulk-rotate-iam-keys.sh` | Entry point: argument handling and action dispatch |
| `layer-1-main-logic.sh` | Info-file parsing and the per-action loops with confirmation prompts |
| `layer-2-aws-logic.sh` | AWS operations (list / create / inactivate / delete) |
| `info/` | User lists |
| `examples/` | Per action: the command and the expected result (no key values) |
| `_HOW_TO_RUN.txt` | Short run example |
| `legacy-single-user/` | Legacy one-user scripts with their own `layer-1.sh`; independent of the bulk script and kept for history |
| `tmp/` | Scratch files written by the script (git-ignored) |

## Security notes

- `create` prints the new **secret access key** to the terminal only. It is kept in
  memory and is never written to a file, so copy it to its destination from the
  terminal (and clear your terminal history/scrollback if needed).
- The only temp file is the `list-access-keys` output (no secrets, just key IDs
  and dates): it is created with `mktemp`, mode 600, and removed on exit.
- Never commit real keys, terminal logs or `*.json` output. Even fake-looking keys
  can trip GitHub push protection, so full transcripts stay in `examples-local/` (git-ignored).
- Use least-privilege profiles rather than full admin where possible.

## Known limitations

- The script stops at the first failed command (`set -Eeuo pipefail`), so one failing user aborts the run for the remaining users.
- A failure while parsing the saved AWS JSON with `jq` inside the read loops is not detected.
