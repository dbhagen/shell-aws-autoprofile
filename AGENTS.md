# AGENTS.md — guidance for agents working in this repo

shell-aws-autoprofile is a small shell add-on: on directory change (and once per shell start) it reads a `.awsprofile` file from the current directory up the tree (falling back to `$HOME`) and exports `AWS_PROFILE` (line 1) and `AWS_REGION` (optional line 2). A line-1 value of `none` clears `AWS_PROFILE`. No build step, no dependencies.

## Layout
- `shell-aws-autoprofile.sh` — the script sourced by Bash (`.bashrc`) and plain ZSH (`.zshrc`) installs.
- `shell-aws-autoprofile.plugin.zsh` — the copy Oh My Zsh loads as a custom plugin.
- `tests/run.sh` — test entrypoint; run under both bash and zsh.
- `.obvious/` — agent orientation: `orientation.md`, `codebase-map.md`, `local-dev.md`, `QA.md`, `config.yml`.
- `README.md` — user-facing install and usage docs. `example.png` — prompt screenshot. `LICENSE` — Apache-2.0.

## The sync rule
`shell-aws-autoprofile.sh` and `shell-aws-autoprofile.plugin.zsh` must stay byte-identical — the plugin copy is what Oh My Zsh loads, the `.sh` copy is what `.bashrc`/`.zshrc` source. Edit both together and verify before committing:

```bash
cmp shell-aws-autoprofile.sh shell-aws-autoprofile.plugin.zsh   # silence = in sync
```

## Conventions
- The GitHub default branch is `master`. Cut feature branches from `origin/master`; PRs merge via squash.
- Tests: `tests/run.sh` runs the synthetic-fixture suite under bash and zsh. Lint: `shellcheck` — keep it clean; see `.obvious/local-dev.md`.
- Verify behavior claims empirically with synthetic `.awsprofile` fixtures and a private `HOME` — no AWS credentials and no network are needed. See `.obvious/QA.md` for the recipe, verified results, and what fixture proofs cannot establish (macOS shells, real Oh My Zsh installs, interactive prompt timing).
- Keep secrets out of git: never commit AWS credentials, real account/profile names, or personal data. `.awsprofile` files belong to individual environments — see the Version Control section of the README.
- Keep PRs scoped to one concern; the PR body states what changed and what was verified, with evidence. Preserve existing behavior and history; new product features stay proposals.
