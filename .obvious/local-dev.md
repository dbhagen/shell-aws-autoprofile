# Local development — shell-aws-autoprofile

Updated 2026-10-09 against head `4f8ce56042b134174e514b20caf146c439b6d3c0`.

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
`tests/run.sh` is the test entrypoint (added by the behavior/test PR of the 2026-10-09 maintenance wave; not present at the docs PR's base commit). It runs the synthetic-fixture suite under both **bash and zsh**:

```bash
bash tests/run.sh
zsh tests/run.sh
```

## Lint gate: shellcheck
`shellcheck` is the lint gate for the scripts. On Debian-family sandboxes: `sudo apt-get install shellcheck` (0.10.0 used for the wave verification).

At head `4f8ce56`, `shellcheck -s bash shell-aws-autoprofile.sh` reports 5 findings (SC1009, SC1073, SC1019, SC1020, SC1072), all from the single malformed test expression guarding the explicit-`none` alert (line 61); `-s zsh shell-aws-autoprofile.plugin.zsh` is clean. Fixing that belongs to the parallel behavior unit; new work should not add findings.

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

Expected output: `AWS_PROFILE=my-profile AWS_REGION=us-east-1`. Swap `bash -s` for `zsh -s` (and source the plugin copy with `ZSH=/path/to/oh-my-zsh` to exercise the Oh My Zsh branch) for the ZSH side. `.obvious/QA.md` records the full scenario matrix and observed results at this head.
