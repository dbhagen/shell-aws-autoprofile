# Codebase map — shell-aws-autoprofile

Line references are to head `97e6ad91aa5a68a955a335a27c9656bdecd8d065` (branch `master`, after behavior PR #4 merged).

| Path | Role |
| --- | --- |
| `shell-aws-autoprofile.sh` | The script — sourced by Bash (`.bashrc`) and plain ZSH (`.zshrc`) installs. |
| `shell-aws-autoprofile.plugin.zsh` | Byte-identical copy of the above, loaded by Oh My Zsh as a custom plugin. Must stay in sync. |
| `tests/run.sh` | Test entrypoint (merged to `master` with PR #4): 72-assertion synthetic-fixture suite, run under both bash and zsh. |
| `README.md` | User-facing install (Bash, Oh My Zsh, plain ZSH) and usage/format documentation. |
| `example.png` | Prompt screenshot embedded by the README from the `master` branch raw URL. |
| `LICENSE` | Apache License 2.0. |
| `.obvious/` | Agent orientation: this map, `orientation.md`, `local-dev.md`, `QA.md`, `config.yml`. |
| `AGENTS.md` | Standing guidance for agents (layout, sync rule, conventions). |

## shell-aws-autoprofile.sh (and its plugin mirror, byte-identical, 117 lines)

| Lines | What |
| --- | --- |
| 1 | Header comment crediting the chpwd-for-bash source. |
| 3-26 | Bash-only prompt machinery, guarded by `[ -n "${BASH_VERSION:-}" ]` so nothing registers under zsh. |
| 6 | `CHPWD_COMMAND` — registry of Bash refresh commands. |
| 9-23 | `_chpwd_hook` — when `$PREVPWD` ≠ `$PWD`, runs every registered command, then updates `PREVPWD`. |
| 25 | Prepends `_chpwd_hook` to `PROMPT_COMMAND`. |
| 28-45 | `awsprofile_find_up` — walk upward until the named file exists; echoes the containing dir (empty when not found). Lines 34-37 normalize a slash-free relative `$PWD` via `command pwd -P`; lines 41-43 break when `%/*` stops shortening — together these prevent an infinite loop (#4 hardening). |
| 47-57 | `awsprofile_find_config` — nearest `.awsprofile`, else `$HOME/.awsprofile`, else the sentinel string `No AWS profile found.` |
| 59-63 | `awsprofile_trim` (added in #4) — strips leading/trailing whitespace from a value. |
| 65-100 | `awsprofile_config_profile` — reset introspection exports (67-68); resolve path, return 1 when none (71-74); read lines 1-2 with `\r` stripped and whitespace trimmed (76-77); reserved-`none` handling at 82-88: exact match on the parsed line-1 value, clear `AWSPROFILE_CONFIG_PROFILE`, print the alert unless `AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE` is exactly `true`; empty-file warning + return 2 at 89-91; export `AWS_PROFILE` (93-94) or **unset** it for `none` (96-97); export `AWS_REGION` only when present (99-100). |
| 102-109 | Hook registration: Bash → append to `CHPWD_COMMAND`; ZSH → `chpwd_functions` when `${ZSH}/oh-my-zsh.sh` exists, else `autoload -Uz add-zsh-hook` + `add-zsh-hook chpwd` (#4 fix for plain ZSH). |
| 111 | Unconditional first run of `awsprofile_config_profile` at source time. |

## Notes
- The two script copies are byte-identical at this head (sha256 `5e528d248b921c53627d84cf694836933451109e8557071d17760182729e5163`).
- Divergences recorded at the wave base `4f8ce56` (dead `none`-alert guard, substring `none` matching, plain-ZSH hook not registering) were fixed by behavior PR #4, merged as `97e6ad9`; see `.obvious/orientation.md` for the history and `.obvious/QA.md` for re-verified behavior.
- No CI exists at wave start; CI wiring lands in a follow-up CI PR.
