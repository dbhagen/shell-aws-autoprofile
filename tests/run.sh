#!/bin/sh
# Behavior suite for shell-aws-autoprofile. Runs under bash and zsh:
#   bash tests/run.sh
#   zsh  tests/run.sh
# Generates synthetic fixtures in temp directories at runtime. No arguments.
# No AWS credentials, no network, no real AWS config (HOME is isolated).
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/shell-aws-autoprofile.sh"
PLUGIN="$ROOT/shell-aws-autoprofile.plugin.zsh"

PASS=0
FAIL=0
BASE=$(mktemp -d "${TMPDIR:-/tmp}/awsprofile-tests-XXXXXX")
FAKE_HOME="$BASE/home"
mkdir -p "$FAKE_HOME"
ROOTFILE_MADE=0

# invoked via trap, not directly
# shellcheck disable=SC2317
cleanup() {
  if [ "$ROOTFILE_MADE" = 1 ]; then sudo -n rm -f /.awsprofile 2>/dev/null; fi
  rm -rf "$BASE"
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# ---- assertion helpers ------------------------------------------------------
ok()   { PASS=$((PASS + 1)); printf 'ok - %s\n' "$1"; }
bad()  {
  FAIL=$((FAIL + 1))
  printf 'NOT OK - %s\n' "$1"
  shift
  while [ $# -gt 0 ]; do printf '      %s\n' "$1"; shift; done
}
check_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected: [$2]" "actual:   [$3]"; fi
}
check_contains() {
  case "$3" in
    *"$2"*) ok "$1" ;;
    *) bad "$1" "expected substring: [$2]" "actual: [$3]" ;;
  esac
}
check_not_contains() {
  case "$3" in
    *"$2"*) bad "$1" "did not expect substring: [$2]" "actual: [$3]" ;;
    *) ok "$1" ;;
  esac
}

# ---- fixture helpers --------------------------------------------------------
mkprof() { # dir line1 line2
  mkdir -p "$1"
  printf '%s\n%s\n' "$2" "$3" > "$1/.awsprofile"
}

# ---- isolated child runners -------------------------------------------------
OUT=''; RC=0; ERR=''
finish_child() {
  RC=$?
  ERR=$(cat "$BASE/err" 2>/dev/null || true)
}
run_bash() { # $1 = child code
  OUT=$(timeout 15 env -i HOME="$FAKE_HOME" PATH="$PATH" TERM="${TERM:-dumb}" \
    bash --noprofile --norc -c "$1" 2>"$BASE/err")
  finish_child
}
run_zsh() { # $1 = child code
  OUT=$(timeout 15 env -i HOME="$FAKE_HOME" PATH="$PATH" TERM="${TERM:-dumb}" \
    zsh -f -c "$1" 2>"$BASE/err")
  finish_child
}
run_bash_exec() { # $1 = cwd, $2 = script path to execute
  OUT=$(cd "$1" && timeout 15 env -i HOME="$FAKE_HOME" PATH="$PATH" TERM="${TERM:-dumb}" \
    bash --noprofile --norc "$2" 2>"$BASE/err")
  finish_child
}
run_zsh_exec() { # $1 = cwd, $2 = script path to execute
  OUT=$(cd "$1" && timeout 15 env -i HOME="$FAKE_HOME" PATH="$PATH" TERM="${TERM:-dumb}" \
    zsh -f "$2" 2>"$BASE/err")
  finish_child
}

# child-side state printer: brackets are <> so zsh never globs them
# child code must expand inside the child shell, so it stays single-quoted
# shellcheck disable=SC2016
CHILD_STATE='
state() {
  if [ -n "${AWS_PROFILE+x}" ]; then echo "STATE ${1} profile=<${AWS_PROFILE}>"; else echo "STATE ${1} profile=<UNSET>"; fi
  if [ -n "${AWS_REGION+x}" ]; then echo "STATE ${1} region=<${AWS_REGION}>"; else echo "STATE ${1} region=<UNSET>"; fi
}'
state_line() { # $1 = e.g. "src profile"
  printf '%s\n' "$OUT" | grep "STATE $1=" | tail -1
}

echo "== T00 byte-identical script copies =="
if cmp -s "$SCRIPT" "$PLUGIN"; then ok "T00 copies byte-identical"; else bad "T00 copies byte-identical" "cmp found differences"; fi

echo "== bash sourcing shell-aws-autoprofile.sh =="
FX="$BASE/t01"; mkprof "$FX" "proj-staging" "us-east-1"
run_bash "$CHILD_STATE
cd '$FX'
source '$SCRIPT'
state src"
check_contains "T01 profile set" "STATE src profile=<proj-staging>" "$(state_line "src profile")"
check_contains "T01 region set" "STATE src region=<us-east-1>" "$(state_line "src region")"

FX="$BASE/t02"; mkprof "$FX/tree" "parentprof" "eu-west-1"; mkdir -p "$FX/tree/deep/nested"
run_bash "$CHILD_STATE
cd '$FX/tree/deep/nested'
source '$SCRIPT'
state src"
check_contains "T02 finds .awsprofile in parent dir" "STATE src profile=<parentprof>" "$(state_line "src profile")"
check_contains "T02 parent region" "STATE src region=<eu-west-1>" "$(state_line "src region")"

FX="$BASE/t03"; mkdir -p "$FX/sub/deeper"
printf 'homeprof\n' > "$FAKE_HOME/.awsprofile"
run_bash "$CHILD_STATE
cd '$FX/sub/deeper'
source '$SCRIPT'
state src"
check_contains "T03 HOME fallback" "STATE src profile=<homeprof>" "$(state_line "src profile")"
rm -f "$FAKE_HOME/.awsprofile"

FX="$BASE/t04"; mkdir -p "$FX"
run_bash "$CHILD_STATE
export AWS_PROFILE=keepme AWS_REGION=us-west-2
cd '$FX'
source '$SCRIPT'
echo \"SRCRC:\$?\"
state after"
check_contains "T04 no config anywhere: rc nonzero" "SRCRC:1" "$OUT"
check_contains "T04 AWS_PROFILE survives" "STATE after profile=<keepme>" "$(state_line "after profile")"
check_contains "T04 AWS_REGION survives" "STATE after region=<us-west-2>" "$(state_line "after region")"
check_contains "T04 clear message" "No .awsprofile file found" "$OUT"

FX="$BASE/t05"; mkdir -p "$FX"; : > "$FX/.awsprofile"
run_bash "$CHILD_STATE
export AWS_PROFILE=keepme AWS_REGION=us-west-2
cd '$FX'
source '$SCRIPT'
echo \"SRCRC:\$?\"
state after"
check_contains "T05 empty file: rc 2" "SRCRC:2" "$OUT"
check_contains "T05 empty file: warning" "Warning: empty .awsprofile" "$OUT"
check_contains "T05 AWS_PROFILE untouched" "STATE after profile=<keepme>" "$(state_line "after profile")"
check_contains "T05 AWS_REGION untouched" "STATE after region=<us-west-2>" "$(state_line "after region")"

FX="$BASE/t06"; mkdir -p "$FX"; printf ' \t \nus-east-1\n' > "$FX/.awsprofile"
run_bash "$CHILD_STATE
export AWS_PROFILE=keepme AWS_REGION=us-west-2
cd '$FX'
source '$SCRIPT'
echo \"SRCRC:\$?\"
state after"
check_contains "T06 whitespace-only line 1: rc 2" "SRCRC:2" "$OUT"
check_contains "T06 whitespace-only line 1: warning" "Warning: empty .awsprofile" "$OUT"
check_contains "T06 whitespace-only line 1: profile survives" "STATE after profile=<keepme>" "$(state_line "after profile")"
check_contains "T06 whitespace-only line 1: region untouched" "STATE after region=<us-west-2>" "$(state_line "after region")"

FX="$BASE/t07"; mkdir -p "$FX"; printf 'crlfprof\r\neu-west-1\r\n' > "$FX/.awsprofile"
run_bash "$CHILD_STATE
cd '$FX'
source '$SCRIPT'
state src"
check_contains "T07 CRLF stripped from profile" "STATE src profile=<crlfprof>" "$(state_line "src profile")"
check_contains "T07 CRLF stripped from region" "STATE src region=<eu-west-1>" "$(state_line "src region")"

FX="$BASE/t08"; mkdir -p "$FX"; printf 'realprof\nus-east-1\nnone\n' > "$FX/.awsprofile"
run_bash "$CHILD_STATE
cd '$FX'
source '$SCRIPT'
state src"
check_contains "T08 'none' on line 3 does not wipe profile" "STATE src profile=<realprof>" "$(state_line "src profile")"
check_contains "T08 region still applied" "STATE src region=<us-east-1>" "$(state_line "src region")"

FX="$BASE/t09"; mkprof "$FX" "nonexistent-thing" "us-east-1"
run_bash "$CHILD_STATE
cd '$FX'
source '$SCRIPT'
state src"
check_contains "T09 profile containing 'none' is kept" "STATE src profile=<nonexistent-thing>" "$(state_line "src profile")"

FX="$BASE/t10"; mkprof "$FX" "none" "eu-central-1"
run_bash "$CHILD_STATE
cd '$FX'
source '$SCRIPT'
echo \"SRCRC:\$?\"
state src"
check_contains "T10 default: alert printed" "explicit 'none' profile found" "$OUT"
check_contains "T10 default: AWS_PROFILE unset (not empty)" "STATE src profile=<UNSET>" "$(state_line "src profile")"
check_contains "T10 region handling unchanged" "STATE src region=<eu-central-1>" "$(state_line "src region")"
check_contains "T10 rc 0" "SRCRC:0" "$OUT"

FX="$BASE/t11"; mkprof "$FX" "none" "eu-central-1"
run_bash "$CHILD_STATE
export AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE=true
cd '$FX'
source '$SCRIPT'
state src"
check_not_contains "T11 suppress=true: alert silenced" "explicit 'none' profile found" "$OUT"
check_contains "T11 suppress=true: AWS_PROFILE still unset" "STATE src profile=<UNSET>" "$(state_line "src profile")"

FX="$BASE/t12"; mkprof "$FX" "none" "eu-central-1"
run_bash "$CHILD_STATE
export AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE=false
cd '$FX'
source '$SCRIPT'
state src"
check_contains "T12 suppress=false: alert printed" "explicit 'none' profile found" "$OUT"
check_contains "T12 suppress=false: AWS_PROFILE unset" "STATE src profile=<UNSET>" "$(state_line "src profile")"

FX="$BASE/t13"; mkdir -p "$FX/my dir name"; printf 'spaceprof\n' > "$FX/my dir name/.awsprofile"
run_bash "$CHILD_STATE
cd '$FX/my dir name'
source '$SCRIPT'
state src"
check_contains "T13 path with spaces" "STATE src profile=<spaceprof>" "$(state_line "src profile")"

run_bash "$CHILD_STATE
export AWS_PROFILE=keepme AWS_REGION=us-west-2
cd /
source '$SCRIPT'
echo \"SRCRC:\$?\"
state root"
check_contains "T14 cwd is filesystem root: rc nonzero" "SRCRC:1" "$OUT"
check_contains "T14 cwd is filesystem root: profile survives" "STATE root profile=<keepme>" "$(state_line "root profile")"
check_contains "T14 cwd is filesystem root: message" "No .awsprofile file found" "$OUT"

echo "== T15 .awsprofile at filesystem root is discovered (skip if no root) =="
if [ -e /.awsprofile ]; then
  printf 'skip - /.awsprofile already exists\n'
elif sudo -n sh -c "printf 'rootprof\n' > /.awsprofile" 2>/dev/null; then
  ROOTFILE_MADE=1
  FX="$BASE/t15"; mkdir -p "$FX/leaf"
  run_bash "$CHILD_STATE
cd '$FX/leaf'
source '$SCRIPT'
state deep"
  check_contains "T15 root file discovered from deep cwd" "STATE deep profile=<rootprof>" "$(state_line "deep profile")"
  sudo -n rm -f /.awsprofile
  ROOTFILE_MADE=0
else
  printf 'skip - cannot create /.awsprofile (no passwordless root)\n'
fi

echo "== bash prompt hook end to end =="
FX="$BASE/t16"; mkprof "$FX/hookA" "hookAprof" "us-east-1"; mkprof "$FX/hookB" "hookBprof" "eu-west-1"; mkdir -p "$FX/hookclean"
run_bash "$CHILD_STATE
cd '$BASE'
source '$SCRIPT'
case \"\$PROMPT_COMMAND\" in _chpwd_hook*) echo PC_OK;; *) echo PC_BAD;; esac
cd '$FX/hookA'
\"\${PROMPT_COMMAND%%;*}\"
state inA
cd '$FX/hookclean'
\"\${PROMPT_COMMAND%%;*}\"
state clean
cd '$FX/hookB'
\"\${PROMPT_COMMAND%%;*}\"
state inB
echo \"PREVPWD_SYNCED:\$([ \"\$PREVPWD\" = \"\$PWD\" ] && echo yes || echo no)\""
check_contains "T16 PROMPT_COMMAND registers hook" "PC_OK" "$OUT"
check_contains "T16 hook: profile on cd into hookA" "STATE inA profile=<hookAprof>" "$(state_line "inA profile")"
check_contains "T16 hook: region on cd into hookA" "STATE inA region=<us-east-1>" "$(state_line "inA region")"
check_contains "T16 hook: profile survives cd to clean dir" "STATE clean profile=<hookAprof>" "$(state_line "clean profile")"
check_contains "T16 hook: profile updates on cd into hookB" "STATE inB profile=<hookBprof>" "$(state_line "inB profile")"
check_contains "T16 hook: region updates on cd into hookB" "STATE inB region=<eu-west-1>" "$(state_line "inB region")"
check_contains "T16 hook: PREVPWD synced" "PREVPWD_SYNCED:yes" "$OUT"

run_bash "$CHILD_STATE
cd '$BASE/t16/hookA'
source '$SCRIPT'
PREVPWD=
\"\${PROMPT_COMMAND%%;*}\" >/dev/null
echo \"GLOB:\$(shopt -p nullglob)\""
check_contains "T17 nullglob not leaked by prompt hook" "GLOB:shopt -u nullglob" "$OUT"

FX="$BASE/t18"; mkprof "$FX" "execprof" ""
run_bash "source '$SCRIPT'
echo CLEAN_SOURCE_RC:\$?"
check_eq "T18a bash source: clean stderr" "" "$ERR"
run_bash_exec "$FX" "$SCRIPT"
check_eq "T18b bash execute: clean stderr" "" "$ERR"
check_eq "T18b bash execute: rc 0 with fixture" "0" "$RC"
run_bash_exec "$BASE" "$SCRIPT"
check_eq "T18c bash execute, no fixture: rc 1" "1" "$RC"
check_eq "T18c bash execute, no fixture: clean stderr" "" "$ERR"
run_zsh_exec "$BASE" "$SCRIPT"
check_eq "T18d zsh execute: clean stderr" "" "$ERR"

echo "== zsh: bash-only bits must not leak =="
run_zsh "$CHILD_STATE
cd '$BASE'
source '$PLUGIN'
echo \"STATE zsh_pc=<\${PROMPT_COMMAND-UNSET}>\"
echo \"STATE zsh_chpwdcmd=<\${CHPWD_COMMAND-UNSET}>\"
case \"\${chpwd_functions[*]-}\" in *awsprofile_config_profile*) echo ZSH_REGISTERED=yes;; *) echo ZSH_REGISTERED=no;; esac"
check_eq "T19 zsh: PROMPT_COMMAND not set" "STATE zsh_pc=<UNSET>" "$(printf '%s\n' "$OUT" | grep 'zsh_pc=')"
check_eq "T19 zsh: CHPWD_COMMAND not set" "STATE zsh_chpwdcmd=<UNSET>" "$(printf '%s\n' "$OUT" | grep 'zsh_chpwdcmd=')"
check_contains "T19 zsh: chpwd hook registered" "ZSH_REGISTERED=yes" "$OUT"
check_eq "T19 zsh: clean stderr" "" "$ERR"

echo "== zsh chpwd hook end to end (plain zsh, .sh copy as README installs) =="
FX="$BASE/t20"; mkprof "$FX/zshA" "zshprofA" "us-east-1"; mkprof "$FX/zshB" "zshprofB" "eu-west-1"
run_zsh "$CHILD_STATE
cd '$BASE'
source '$SCRIPT'
cd '$FX/zshA'
state inA
cd '$FX/zshB'
state inB"
check_contains "T20 plain zsh .sh: hook fires on cd" "STATE inA profile=<zshprofA>" "$(state_line "inA profile")"
check_contains "T20 plain zsh .sh: region applied" "STATE inA region=<us-east-1>" "$(state_line "inA region")"
check_contains "T20 plain zsh .sh: hook updates on second cd" "STATE inB profile=<zshprofB>" "$(state_line "inB profile")"
check_eq "T20 plain zsh .sh: clean stderr" "" "$ERR"

echo "== zsh chpwd hook end to end (plain zsh, plugin copy) =="
run_zsh "$CHILD_STATE
cd '$BASE'
source '$PLUGIN'
cd '$FX/zshA'
state inA
cd '$FX/zshB'
state inB"
check_contains "T21 plain zsh plugin: hook fires on cd" "STATE inA profile=<zshprofA>" "$(state_line "inA profile")"
check_contains "T21 plain zsh plugin: hook updates on cd" "STATE inB profile=<zshprofB>" "$(state_line "inB profile")"
check_eq "T21 plain zsh plugin: clean stderr" "" "$ERR"

echo "== zsh Oh My Zsh detection branch =="
FX="$BASE/t22"; mkprof "$FX/omzproj" "omzprof" "us-east-2"; mkdir -p "$BASE/fakeomz"; : > "$BASE/fakeomz/oh-my-zsh.sh"
run_zsh "export ZSH='$BASE/fakeomz'
$CHILD_STATE
cd '$BASE'
source '$PLUGIN'
case \"\${chpwd_functions[*]-}\" in *awsprofile_config_profile*) echo OMZ_REGISTERED=yes;; *) echo OMZ_REGISTERED=no;; esac
cd '$FX/omzproj'
state inproj"
check_contains "T22 OMZ branch registers hook" "OMZ_REGISTERED=yes" "$OUT"
check_contains "T22 OMZ branch: hook fires on cd" "STATE inproj profile=<omzprof>" "$(state_line "inproj profile")"
check_eq "T22 OMZ branch: clean stderr" "" "$ERR"

echo "== zsh alert states =="
FX="$BASE/t23"; mkprof "$FX" "none" "eu-central-1"
run_zsh "$CHILD_STATE
cd '$FX'
source '$PLUGIN'
state src"
check_contains "T23 zsh default: alert printed" "explicit 'none' profile found" "$OUT"
check_contains "T23 zsh default: AWS_PROFILE unset" "STATE src profile=<UNSET>" "$(state_line "src profile")"
run_zsh "export AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE=true
$CHILD_STATE
cd '$FX'
source '$PLUGIN'
state src"
check_not_contains "T23 zsh suppress=true: alert silenced" "explicit 'none' profile found" "$OUT"
check_contains "T23 zsh suppress=true: AWS_PROFILE unset" "STATE src profile=<UNSET>" "$(state_line "src profile")"

echo "== find-up hardening: slash-free relative PWD must not hang =="
FX="$BASE/t24"; mkdir -p "$FX"
run_bash "$CHILD_STATE
export AWS_PROFILE=keepme
cd '$FX'
PWD=slashfree source '$SCRIPT'
echo \"SRCRC:\$?\"
state after"
check_contains "T24 bash: message printed" "No .awsprofile file found" "$OUT"
check_contains "T24 bash: AWS_PROFILE survives" "STATE after profile=<keepme>" "$(state_line "after profile")"
run_zsh "$CHILD_STATE
export AWS_PROFILE=keepme
cd '$FX'
PWD=slashfree
source '$PLUGIN'
echo \"SRCRC:\$?\"
state after"
check_contains "T24 zsh: message printed" "No .awsprofile file found" "$OUT"
check_contains "T24 zsh: AWS_PROFILE survives" "STATE after profile=<keepme>" "$(state_line "after profile")"

echo
echo "passed: $PASS   failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
