# Codebase map — shell-aws-autoprofile

Line references are to head `4f8ce56042b134174e514b20caf146c439b6d3c0`.

| Path | Role |
| --- | --- |
| `shell-aws-autoprofile.sh` | The script — sourced by Bash (`.bashrc`) and plain ZSH (`.zshrc`) installs. |
| `shell-aws-autoprofile.plugin.zsh` | Byte-identical copy of the above, loaded by Oh My Zsh as a custom plugin. Must stay in sync. |
| `tests/run.sh` | Test entrypoint (lands with the behavior/test PR of the 2026-10-09 wave); runs the fixture suite under bash and zsh. Not present at the docs PR's base commit. |
| `README.md` | User-facing install (Bash, Oh My Zsh, plain ZSH) and usage/format documentation. |
| `example.png` | Prompt screenshot embedded by the README from the `master` branch raw URL. |
| `LICENSE` | Apache License 2.0. |
| `.obvious/` | Agent orientation: this map, `orientation.md`, `local-dev.md`, `QA.md`, `config.yml`. |
| `AGENTS.md` | Standing guidance for agents (layout, sync rule, conventions). |

## shell-aws-autoprofile.sh (and its plugin mirror, byte-identical)

| Lines | What |
| --- | --- |
| 1-3 | Header comment crediting the chpwd-for-bash source. |
| 4 | `CHPWD_COMMAND` — registry of Bash refresh commands. |
| 6-21 | `_chpwd_hook` — Bash hook; when `$PREVPWD` ≠ `$PWD`, runs every registered command, then updates `PREVPWD`. |
| 24 | Prepends `_chpwd_hook` to `PROMPT_COMMAND`. |
| 26-33 | `awsprofile_find_up` — walk `$PWD` upward until the named file exists; echoes the containing dir (empty when not found). |
| 35-47 | `awsprofile_find_config` — nearest `.awsprofile`, else `$HOME/.awsprofile`, else the sentinel string `No AWS profile found.` |
| 49-73 | `awsprofile_config_profile` — reset introspection exports; resolve path (return 1 if none); read lines 1-2 with `\r` stripped; reserved-`none` handling at 60-66 (clear profile, alert behind a guard); empty-file warning + return 2 at 65-67; export `AWS_PROFILE` (69) and `AWS_REGION` (70-72, only when present). |
| 75-83 | Shell detection and hook registration (Bash → `CHPWD_COMMAND`; ZSH → `chpwd_functions` under Oh My Zsh, else `add-zsh-hook chpwd`). |
| 84 | Unconditional first run of `awsprofile_config_profile` at source time. |

## Notes
- The two script copies are byte-identical at this head (sha256 `deefb79f9880ea02ae48abd017692434d35b82eaeffd84c083a744272c48b522`).
- Behavior observed at this head that the parallel behavior unit is fixing (malformed alert guard, substring `none` matching, plain-ZSH hook registration) is recorded in `.obvious/orientation.md` and `.obvious/QA.md`.
- No CI exists at wave start; CI wiring lands in a follow-up CI PR.
