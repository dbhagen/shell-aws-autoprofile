# Local development — shell-aws-autoprofile

Updated 2026-10-09 against head `97e6ad91aa5a68a955a335a27c9656bdecd8d065` (branch `master`, after behavior PR #4 merged).

## There is no build step
The product is two byte-identical shell scripts. Clone, source, done — no compiler, package manager, or dependency install. To try it locally:

```bash
source ./shell-aws-autoprofile.sh   # registers itself and applies the nearest .awsprofile once
```

## The sync rule
Edit `shell-aws-autoprofile.sh` and `shell-aws-autoprofile.plugin.zsh` together — the `.plugin.zsh` copy is what Oh My Zsh loads; the `.sh` copy is what `.bashrc`/`.zshrc` source. Verify before committing:

```bash
cmp shell-aws-autoprofile.sh shell-aws-autoprofile.plugin.zsh   # silence = in sync
```

## Tests
`tests/run.sh` is the test entrypoint, merged to `master` with the behavior/test PR #4. It runs the 72-assertion synthetic-fixture suite under both **bash and zsh** — verified green on both at `97e6ad9`:

```bash
bash tests/run.sh
zsh tests/run.sh
```

## Lint gate: shellcheck
`shellcheck` is the lint gate for the scripts. On Debian-family sandboxes: `sudo apt-get install shellcheck` (0.10.0 used for the wave verification).

At `97e6ad9`, `shellcheck -s bash shell-aws-autoprofile.sh` is **clean** — the 5 findings present at the wave base (SC1009, SC1073, SC1019, SC1020, SC1072, all from the old malformed alert guard) were fixed by PR #4. Note shellcheck has no zsh dialect (`-s zsh` is rejected with `Unknown shell`), so the plugin copy is kept lint-clean via byte-identity with the `.sh` copy (`cmp`); new work should not add bash-mode findings.

## Manual fixture verification (no AWS credentials, no network)
For one-off checks, run the script inside a disposable environment with a private `HOME` and synthetic `.awsprofile` fixtures:

```bash
T=$(mktemp -d) && mkdir -p "$T/proj"
printf 'my-profile\nus-east-1\n' > "$T/proj/.awsprofile"
env -i HOME="$T/home" PATH="$PATH" SCRIPT="$PWD/shell-aws-autoprofile.sh" T="$T" bash -s <<'EOF'
source "$SCRIPT"
cd "$T/proj"
awsprofile_config_profile
echo "AWS_PROFILE=$AWS_PROFILE AWS_REGION=$AWS_REGION"
EOF
```

Expected output: `AWS_PROFILE=my-profile AWS_REGION=us-east-1`. Values are whitespace-trimmed; CRLF endings are stripped. Swap `bash -s` for `zsh -s` (and export `ZSH=/path/to/oh-my-zsh` containing an `oh-my-zsh.sh` file to exercise the Oh My Zsh branch; without it the plain-ZSH `autoload add-zsh-hook` branch registers) for the ZSH side. `.obvious/QA.md` records the full 24-scenario matrix and observed results at this head.
