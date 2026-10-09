# Orientation — shell-aws-autoprofile

Updated 2026-10-09 against head `97e6ad91aa5a68a955a335a27c9656bdecd8d065` (branch `master`, after behavior PR #4 merged).

## What this repo is
A small shell add-on for Bash and ZSH. On every directory change (and once per shell start) it looks for a `.awsprofile` file from the current directory upward, falls back to `$HOME/.awsprofile`, and exports `AWS_PROFILE` (line 1) and `AWS_REGION` (optional line 2). A line-1 value of exactly `none` unsets `AWS_PROFILE` (region still applied). There is no build step, no dependency manager, and (at wave start) no CI: the product is two byte-identical script copies, a fixture test suite, plus docs.

## Runtime model
- The user sources the script from `.bashrc` / `.zshrc` (or Oh My Zsh loads the plugin copy from its custom plugins folder).
- Sourcing registers a refresh hook and immediately calls the profile function once.
- On Bash the hook rides `PROMPT_COMMAND` (evaluated before each prompt); on ZSH it rides `chpwd_functions` (Oh My Zsh) or `add-zsh-hook chpwd` after `autoload -Uz add-zsh-hook` (plain ZSH), firing on every `cd`.
- Each refresh re-resolves the nearest `.awsprofile` and re-exports the environment.

## Function walk
Line references are to head `97e6ad9` (`shell-aws-autoprofile.sh`, 117 lines; the plugin copy is byte-identical).

1. **Bash-only prompt machinery (lines 3-26, guarded by `${BASH_VERSION:-}`).** `CHPWD_COMMAND` (line 6) is a semicolon-separated registry of Bash refresh commands. `_chpwd_hook` (lines 9-23) runs every registered command when `$PREVPWD` differs from `$PWD`, then re-records `PREVPWD`. Line 25 prepends `_chpwd_hook` to `PROMPT_COMMAND`. The guard means none of this registers under zsh.
2. **`awsprofile_find_up` (lines 28-45).** Walks the search start upward by stripping the trailing path component until `${path}/.awsprofile` exists, then echoes the containing directory; echoes an empty string when nothing is found. Hardening (merged in #4): a slash-free relative `$PWD` (only possible via an override; a real `cd` always yields an absolute path) is first normalized with `command pwd -P` (lines 34-37), and the loop breaks when `%/*` stops shortening (lines 41-43), so it cannot loop forever.
3. **`awsprofile_find_config` (lines 47-57).** Uses `${dir}/.awsprofile` when it exists, else `$HOME/.awsprofile`, else echoes the literal string `No AWS profile found.` — which fails the caller's existence check and drives the not-found path.
4. **`awsprofile_trim` (lines 59-63, added in #4).** Trims leading/trailing whitespace from a value via `%%`/`##` pattern expansion.
5. **`awsprofile_config_profile` (lines 65-100).** The entry point. Resets the introspection exports `AWSPROFILE_CONFIG_PROFILE` / `AWSREGION_CONFIG_REGION` (67-68); resolves the config path; returns 1 with `No .awsprofile file found` when there is none (71-74); reads lines 1 and 2 (`sed -n 1p` / `sed -n 2p`, piped through `tr -d '\r'` and `awsprofile_trim`, 76-77); applies the reserved-`none` rule by exact match on the parsed line-1 value (83): on match, clears `AWSPROFILE_CONFIG_PROFILE` and — unless `AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE` is exactly `true` (84-86) — prints the alert `explicit 'none' profile found in .awsprofile file, unsetting profile`; an empty (after trim) line 1 instead warns `Warning: empty .awsprofile file found at "..."` and returns 2 (89-91). Finally: a non-empty profile is exported as `AWS_PROFILE` (93-94), otherwise `AWS_PROFILE` is **unset** (96-97, the fixed #4 semantics — the variable ceases to exist); the region is exported as `AWS_REGION` only when non-empty (99-100).
6. **Registration (lines 102-109).** Bash appends `awsprofile_config_profile` to `CHPWD_COMMAND`; ZSH appends to `chpwd_functions` when `${ZSH}/oh-my-zsh.sh` exists (real Oh My Zsh install), else registers via `autoload -Uz add-zsh-hook` + `add-zsh-hook chpwd` (plain ZSH — the #4 fix).
7. **Startup call (line 111).** The function runs once unconditionally at source time.

## Environment variables
- Exported by the script: `AWS_PROFILE`, `AWS_REGION`, `AWSPROFILE_CONFIG_PROFILE` (profile as read, whitespace-trimmed), `AWSREGION_CONFIG_REGION` (region as read, whitespace-trimmed).
- Read from the environment: `AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE` — only the exact string `true` suppresses the explicit-`none` alert; any other value (including `false` and `1`) leaves the alert in place.

## History: divergences at the wave base `4f8ce56`, fixed by PR #4 (`97e6ad9`)
Recorded at the wave base by this unit's fixture harness, re-verified fixed on `97e6ad9` (see `.obvious/QA.md`):
- the explicit-`none` alert never printed (malformed test expression at old line 61, shellcheck SC1073/SC1019/SC1020/SC1072) and the suppressor was a no-op → alert prints by default, silenced only by exactly `true`;
- `grep -q none` matched the word anywhere in the file, wiping `AWS_PROFILE` for names like `nonexistent-profile` → exact-match on the parsed line-1 value now;
- plain-ZSH installs sourcing the `.sh` copy registered no chpwd hook (tail-of-`$0` detection), and bare-zsh plugin installs hit an unautoloaded `add-zsh-hook` → registration now keys off `${ZSH_VERSION:-}` / `${BASH_VERSION:-}` and autoloads `add-zsh-hook`.
Additional #4 behavior this unit verified: whitespace-only line 1 is treated as an empty file (warning, rc 2, environment untouched), values are whitespace-trimmed, and `awsprofile_find_up` normalizes via `pwd -P` (hardening).

## Pointers
- File-by-file map: `.obvious/codebase-map.md`
- Development workflow: `.obvious/local-dev.md`
- QA path, coverage, verified results, and platform boundaries: `.obvious/QA.md`
