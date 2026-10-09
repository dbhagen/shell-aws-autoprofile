# QA — shell-aws-autoprofile

Updated 2026-10-09 against head `97e6ad91aa5a68a955a335a27c9656bdecd8d065` (branch `master`, after behavior PR #4 merged).

## QA path
`tests/run.sh` — the synthetic-fixture suite added by the behavior/test unit and merged to `master` in PR #4. Run it under both shells:

```bash
bash tests/run.sh   # verified: passed 72, failed 0
zsh tests/run.sh    # verified: passed 72, failed 0
```

CI wiring (running shellcheck, both-shell test runs, and the byte-identity check on push/PR) lands in a follow-up CI PR; at wave start the repo has no CI. Until that lands, run the suite locally as above.

## Coverage
The suite exercises, per shell: nearest-file lookup and parent-directory find-up; `$HOME` fallback; the no-file path (message, rc 1, environment preserved); the optional region line; extra lines ignored; whitespace trimming and CRLF stripping; the empty-file warning (rc 2); the reserved `none` profile unsetting `AWS_PROFILE` (region still applied); the alert printing by default and `AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE` suppressing it; hook registration (Bash `PROMPT_COMMAND`, ZSH `chpwd` including the plain-ZSH `autoload add-zsh-hook` path) and refresh on directory change; and byte-identical script copies.

## Independently verified (docs-unit fixture matrix; bash 5.2.37 / zsh 5.9, Debian GNU/Linux sandbox)
24-scenario matrix (S1-S18, two multi-assert scenarios) run against the merged `97e6ad9` scripts: sourcing the current scripts with synthetic `.awsprofile` fixtures in disposable `env -i` environments (per-scenario scratch cwd, private `HOME`; no network, no AWS credentials, no real personal data). Result: **24 passed, 0 failed**.

| Scenario | Observed at `97e6ad9` |
| --- | --- |
| fixture in cwd | `AWS_PROFILE`/`AWS_REGION` set (rc=0); `AWSPROFILE_CONFIG_PROFILE`/`AWSREGION_CONFIG_REGION` mirror the trimmed file values |
| file in parent dir | found via find-up from a nested directory; nearest file wins over `$HOME` |
| no file up-tree, `$HOME/.awsprofile` present | HOME fallback used |
| no file anywhere | prints `No .awsprofile file found` (once per evaluation), rc=1; previously-set `AWS_PROFILE`/`AWS_REGION` preserved; introspection vars reset to empty |
| extra lines beyond line 2 | ignored (only lines 1-2 read) |
| line 2 empty or missing | profile set; `AWS_REGION` left untouched |
| surrounding whitespace / CRLF | trimmed from both values (`awsprofile_trim` + `\r` strip) |
| empty file | `Warning: empty .awsprofile file found at "..."`, rc=2, environment untouched |
| whitespace-only line 1 | treated as empty: same warning, rc=2, environment untouched |
| `none` on line 1 | `AWS_PROFILE` **unset** — the variable no longer exists afterward (checked with the `${AWS_PROFILE-UNSET}` sentinel); region still applied; rc=0 |
| `none` alert | prints by default: `explicit 'none' profile found in .awsprofile file, unsetting profile` |
| suppressor `true` | alert silenced (exact string match) |
| suppressor `false` / `1` / `TRUE` / unset | alert still prints — only the exact string `true` suppresses |
| `nonexistent-profile` on line 1, `us-none-1` on line 2 | ordinary profile: both values applied, no wipe — `none` no longer matches as a substring |
| Bash refresh | `PROMPT_COMMAND` hook (`_chpwd_hook` → `CHPWD_COMMAND`) re-reads the profile after `cd` |
| ZSH refresh (Oh My Zsh path, `${ZSH}/oh-my-zsh.sh` present) | `chpwd_functions` registration; hook fires on `cd` |
| ZSH plain installs (`.sh` or `.plugin.zsh`, no OMZ) | `autoload -Uz add-zsh-hook` + `add-zsh-hook chpwd`; hook fires on `cd` — the plain-ZSH refresh gap from the pre-#4 head is fixed |
| `pwd -P` hardening | with a slash-free relative `$PWD` override (the historical infinite-loop risk), `awsprofile_find_up` normalizes to the physical directory and terminates |
| script copies | byte-identical: sha256 `5e528d248b921c53627d84cf694836933451109e8557071d17760182729e5163` for both |
| `set -u` hygiene | sourcing and running under `set -u` produces no unbound-variable errors |

Representative proof commands (full matrix output captured at verification time; pattern also in `.obvious/local-dev.md`):

```bash
T=$(mktemp -d) && mkdir -p "$T/proj"
printf 'none\nus-east-1\n' > "$T/proj/.awsprofile"
env -i HOME="$T/home" PATH="$PATH" SCRIPT="$PWD/shell-aws-autoprofile.sh" T="$T" bash -s <<'EOF'
cd "$T/home"  # clean scratch: the startup call at source finds nothing here
source "$SCRIPT"; cd "$T/proj"
awsprofile_config_profile; echo "rc=$? AWS_PROFILE=<${AWS_PROFILE-UNSET}> AWS_REGION=<${AWS_REGION-UNSET}>"
EOF
# observed: explicit 'none' profile found in .awsprofile file, unsetting profile
#           rc=0 AWS_PROFILE=<UNSET> AWS_REGION=<us-east-1>

bash tests/run.sh && zsh tests/run.sh   # passed: 72, failed: 0 (both)
```

## History: divergences observed pre-#4, now fixed
At the wave's base head `4f8ce56` this unit recorded three divergences between the documented contract and observed behavior; PR #4 (merged as `97e6ad9`) fixed all three, and the rows above re-verify them on the fixed scripts:
- the explicit-`none` alert never fired (malformed test expression, shellcheck SC1073/SC1019/SC1020/SC1072) and `AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE` was a no-op → alert now prints by default and is silenced only by the exact string `true`;
- `grep -q none` cleared `AWS_PROFILE` for any `none` substring anywhere in the file → reserved value now matches the parsed, trimmed line-1 profile exactly;
- plain-ZSH installs sourcing the `.sh` copy registered no chpwd hook (and bare-zsh plugin installs hit an unautoloaded `add-zsh-hook`) → both paths now register via `autoload -Uz add-zsh-hook`.

## Platform boundaries — what these proofs cannot establish
All verification ran on a Debian GNU/Linux sandbox with bash 5.2.37 and zsh 5.9. Fixture proofs on Linux **cannot** establish:
- macOS/BSD shells (the primary platform for this repo): system bash 3.2, Homebrew zsh, macOS `sed`/`grep` behavior differences.
- Behavior inside a real Oh My Zsh install and specific OMZ versions, or alongside other prompt frameworks (Spaceship, Bash-IT) that also touch `PROMPT_COMMAND`/`chpwd`. The OMZ-path verification here used a minimal `${ZSH}/oh-my-zsh.sh` fixture, exercising the script's own registration branch only.
- Interactive-shell behavior: real prompt refresh cadence and terminal rendering in a live session.
- That the AWS CLI/SDKs themselves resolve credentials from the exported `AWS_PROFILE`/`AWS_REGION` — no AWS credentials were used and no network calls were made, by design.
- Any hardware-dependent behavior (Stream Deck or other devices are out of scope for this repo).

All fixtures were disposable synthetic files; no real financial, mail, message, or home datasets were read.
