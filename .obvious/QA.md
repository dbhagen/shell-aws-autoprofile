# QA — shell-aws-autoprofile

Updated 2026-10-09 against head `4f8ce56042b134174e514b20caf146c439b6d3c0` (branch `master`).

## QA path
`tests/run.sh` — the synthetic-fixture suite added by the behavior/test unit of the 2026-10-09 maintenance wave (not present at the docs PR's base commit). Run it under both shells:

```bash
bash tests/run.sh
zsh tests/run.sh
```

CI wiring (running these on push/PR) lands in a follow-up CI PR; at wave start the repo has no CI. Until that lands, run the suite locally as above.

## Coverage
The suite exercises, per shell: nearest-file lookup and parent-directory find-up; `$HOME` fallback; the no-file path (message + preserved environment); the optional region line; extra lines ignored; CRLF stripping; the empty-file warning; the reserved `none` profile clearing `AWS_PROFILE` (region still applied); `AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE=true` suppressing the `none` alert; hook registration (Bash `PROMPT_COMMAND`, ZSH `chpwd`) and refresh on directory change; and byte-identical script copies.

## Verified at this head (docs-unit fixture harness; bash 5.2.37 / zsh 5.9, Debian GNU/Linux sandbox)
Observed results from sourcing the current scripts with synthetic fixtures in disposable `env -i` environments (private `HOME`, temp dirs under `/tmp`; no network, no AWS credentials, no real personal data):

| Scenario | Observed at `4f8ce56` |
| --- | --- |
| fixture in cwd | `AWS_PROFILE`/`AWS_REGION` set (rc=0); `AWSPROFILE_CONFIG_PROFILE`/`AWSREGION_CONFIG_REGION` mirror the file values |
| file in parent dir | found via find-up from a nested directory; nearest file wins |
| no file up-tree, `$HOME/.awsprofile` present | HOME fallback used |
| no file anywhere | prints `No .awsprofile file found`, rc=1; previously-set `AWS_PROFILE`/`AWS_REGION` preserved; introspection vars reset to empty |
| extra lines beyond line 2 | ignored (only lines 1-2 read) |
| line 2 empty or missing | profile set; `AWS_REGION` left untouched |
| CRLF file | `\r` stripped from both values |
| empty file | `Warning: empty .awsprofile file found at "..."`, rc=2, environment untouched |
| `none` on line 1 | `AWS_PROFILE` cleared (empty string); region still applied |
| suppressor `true` / `false` / `1` / unset | no observable difference — see gaps below |
| `none` as substring (`nonexistent-profile` on line 1, `us-none-1` on line 2) | also clears `AWS_PROFILE` — see gaps below |
| Bash refresh | `PROMPT_COMMAND` hook (`_chpwd_hook` → `CHPWD_COMMAND`) re-reads the profile after `cd` on prompt evaluation |
| ZSH refresh (Oh My Zsh path, `ZSH` tail `oh-my-zsh`) | `chpwd_functions` registers the function and the hook fires on `cd`; profile follows the directory |
| script copies | byte-identical: sha256 `deefb79f9880ea02ae48abd017692434d35b82eaeffd84c083a744272c48b522` for both files |

Representative proof command (full matrix in the harness output; pattern also in `.obvious/local-dev.md`):

```bash
T=$(mktemp -d) && mkdir -p "$T/proj"
printf 'none\nus-east-1\n' > "$T/proj/.awsprofile"
env -i HOME="$T/home" PATH="$PATH" SCRIPT="$PWD/shell-aws-autoprofile.sh" T="$T" bash -s <<'EOF'
source "$SCRIPT"; cd "$T/proj"
awsprofile_config_profile; echo "rc=$? AWS_PROFILE=<${AWS_PROFILE-UNSET}> AWS_REGION=<${AWS_REGION-UNSET}>"
EOF
# observed: rc=0 AWS_PROFILE=<> AWS_REGION=<us-east-1>
```

## Known gaps at this head (owned by the parallel behavior unit)
- The explicit-`none` alert never prints: the guard (line 61) is a malformed test expression — shellcheck flags SC1073/SC1019/SC1020/SC1072 there — so the alert path is dead and `AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE` is a no-op at this head. The README documents the intended semantics: alert by default, suppressed when the variable is `true`.
- `none` is matched as a substring anywhere in the file (`grep -q none`), not as an exact line-1 value: a profile named `nonexistent-profile`, or a region containing `none`, also clears `AWS_PROFILE`.
- Plain-ZSH installs source the `.sh` copy, whose tail (`.sh`) fails the ZSH detection, so no chpwd hook registers — the profile is set once at startup and not refreshed on `cd`. In bare zsh without Oh My Zsh, the plugin copy hits an unautoloaded `add-zsh-hook` (command not found).

## Platform boundaries — what these proofs cannot establish
All verification ran on a Debian GNU/Linux sandbox with bash 5.2.37 and zsh 5.9. Fixture proofs on Linux **cannot** establish:
- macOS/BSD shells (the primary platform for this repo): system bash 3.2, Homebrew zsh, macOS `sed`/`grep` behavior differences.
- Behavior inside a real Oh My Zsh install and specific OMZ versions, or alongside other prompt frameworks (Spaceship, Bash-IT) that also touch `PROMPT_COMMAND`/`chpwd`.
- Interactive-shell behavior: real prompt refresh cadence and terminal rendering in a live session.
- That the AWS CLI/SDKs themselves resolve credentials from the exported `AWS_PROFILE`/`AWS_REGION` — no AWS credentials were used and no network calls were made, by design.
- Any hardware-dependent behavior (Stream Deck or other devices are out of scope for this repo).

All fixtures were disposable synthetic files; no real financial, mail, message, or home datasets were read.
