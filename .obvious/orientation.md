# Orientation — shell-aws-autoprofile

Updated 2026-10-09 against head `4f8ce56042b134174e514b20caf146c439b6d3c0` (branch `master`).

## What this repo is
A small shell add-on for Bash and ZSH. On every directory change (and once per shell start) it looks for a `.awsprofile` file from the current directory upward, falls back to `$HOME/.awsprofile`, and exports `AWS_PROFILE` (line 1) and `AWS_REGION` (optional line 2). A line-1 value of `none` clears `AWS_PROFILE`; a region on line 2 is still honored. There is no build step, no dependency manager, and (at wave start) no CI: the product is two byte-identical script copies plus docs.

## Runtime model
- The user sources the script from `.bashrc` / `.zshrc` (or Oh My Zsh loads the plugin copy from its custom plugins folder).
- Sourcing registers a refresh hook and immediately calls the profile function once.
- On Bash the hook rides `PROMPT_COMMAND` (evaluated before each prompt); on ZSH it rides `chpwd_functions` (Oh My Zsh) or `add-zsh-hook chpwd` (plain ZSH), firing on every `cd`.
- Each refresh re-resolves the nearest `.awsprofile` and re-exports the environment.

## Function walk
Line references are to head `4f8ce56`.

1. **Shell detection (lines 75-83).** Selects wiring by the tail of `$0`: Bash matches when the last 4 characters (`${0:${#0}-4:4}`) are `bash`; ZSH matches when the last 3 (`${0[-3,-1]}`) are `zsh`. ZSH sets `$0` to the sourced file during `source`, so the `.plugin.zsh` copy matches and the plain `.sh` copy (tail `.sh`) does not — see the observations below. Under Oh My Zsh (`${ZSH[-9,-1]}` = `oh-my-zsh`) the function is appended to `chpwd_functions`; otherwise `add-zsh-hook chpwd` registers it.
2. **`_chpwd_hook` (lines 6-21, Bash only).** Prepended to `PROMPT_COMMAND` (line 24). When `$PREVPWD` differs from `$PWD`, it runs every command listed in the semicolon-separated `$CHPWD_COMMAND` registry, then re-records `PREVPWD`.
3. **`awsprofile_find_up` (lines 26-33).** Walks `$PWD` upward by stripping the trailing path component until `${path}/.awsprofile` exists, then echoes the containing directory; echoes an empty string when nothing is found.
4. **`awsprofile_find_config` (lines 35-47).** Uses `${dir}/.awsprofile` when it exists, else `$HOME/.awsprofile`, else echoes the literal string `No AWS profile found.` — which fails the caller's existence check and drives the not-found path.
5. **`awsprofile_config_profile` (lines 49-73).** The entry point. Resets the introspection exports `AWSPROFILE_CONFIG_PROFILE` / `AWSREGION_CONFIG_REGION`; resolves the config path; returns 1 with `No .awsprofile file found` when there is none; reads line 1 / line 2 (`sed -n 1p` / `sed -n 2p`, each piped through `tr -d '\r'`); applies the reserved-`none` rule (`grep -q none` over the file, clearing the profile and, when the guard worked, printing an alert); warns and returns 2 on an empty file; finally exports `AWS_PROFILE` and — only when a region line is present — `AWS_REGION`.
6. **Startup call (line 84).** The function runs once unconditionally at source time.

## Environment variables
- Exported by the script: `AWS_PROFILE`, `AWS_REGION`, `AWSPROFILE_CONFIG_PROFILE` (profile exactly as read from the file), `AWSREGION_CONFIG_REGION` (region exactly as read).
- Read from the environment: `AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE=true` suppresses the explicit-`none` alert message.

## Current-head observations (owned by the parallel behavior unit)
Recorded from the fixture harness on this head so docs and code reconcile visibly. The scripts are outside the docs unit's scope; the README documents the intended contract.
- The explicit-`none` alert never prints: the guard at line 61 is a malformed test expression (`[[ -z "${V}"] && ["$V" = true ]]` — shellcheck SC1073/SC1019/SC1020/SC1072). `AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE` is therefore a no-op at this head.
- `grep -q none` (line 60) matches the word anywhere in the file, not just as an exact line-1 value — e.g. a profile named `nonexistent-profile` or a region containing `none` also clears `AWS_PROFILE`.
- Plain-ZSH installs source the `.sh` copy, whose tail fails the ZSH detection, so no chpwd hook registers: the profile is set once at startup and not refreshed on `cd`. The plugin copy registers correctly under Oh My Zsh (verified: hook fires on `cd`), and in bare zsh without Oh My Zsh the plugin copy hits an unautoloaded `add-zsh-hook` (command not found).

## Pointers
- File-by-file map: `.obvious/codebase-map.md`
- Development workflow: `.obvious/local-dev.md`
- QA path, coverage, verified results, and platform boundaries: `.obvious/QA.md`
