#!/usr/bin/env bash
# NovaSmart lab — environment parity check.
# Reference: the lab image of 2026-08-05.
# Exit: 0 all pass · 1 drift · 2 something missing · 3 cannot run (no venv)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LAB_HOME="${LAB_HOME:-$HOME/novasmart-lab}"
LAB_ROOT="${LAB_ROOT:-$HOME}"
SESSION="$LAB_ROOT/Desktop/Session1"

JSON=0; HINTS=0; READINESS=0
for a in ${@+"$@"}; do
  case "$a" in
    --json) JSON=1 ;;
    --fix-hints) HINTS=1 ;;
    --readiness) READINESS=1; HINTS=1 ;;
    -h|--help) sed -n '2,5p' "$0"; echo "Usage: verify.sh [--json] [--fix-hints] [--readiness]"; exit 0 ;;
  esac
done

VENV="$LAB_HOME/.venv"
PY="$VENV/bin/python"
[ -x "$PY" ] || PY="$(command -v python3 || true)"

pass=0; drift=0; missing=0
ROWS=()

chk() { # name  match  found  mode(exact|prefix|any)  display  hint
  local n=$1 e=$2 f=$3 m=${4:-exact} d=${5:-$2} hint=${6:-} s=DRIFT
  if   [ -z "$f" ];       then s=MISSING
  elif [ "$m" = any ];    then s=OK
  elif [ "$m" = prefix ]; then case "$f" in "$e"*) s=OK ;; esac
  elif [ "$e" = "$f" ];   then s=OK
  fi
  case $s in OK) pass=$((pass+1));; DRIFT) drift=$((drift+1));; MISSING) missing=$((missing+1));; esac
  ROWS+=("$n|$d|${f:-—}|$s|$hint")
}
ver() { "$PY" -c "import importlib.metadata as m;print(m.version('$1'))" 2>/dev/null; }

if [ ! -x "$VENV/bin/python" ]; then
  [ "$JSON" = 1 ] && echo '{"status":"cannot-run","reason":"no venv at '"$VENV"'"}' \
                  || echo "cannot run: no virtual environment at $VENV — see install.sh --only python"
  exit 3
fi

chk python       "3.14"   "$("$PY" -c 'import platform;print(platform.python_version())' 2>/dev/null)" prefix "3.14.x"           "install.sh --only python"
chk node         "24."    "$(node -v 2>/dev/null | tr -d v)"                                          prefix "24.x"             "install.sh --only tools"
chk gcloud       ""       "$(gcloud version 2>/dev/null | awk '/Google Cloud SDK/{print $4}')"        any    "any (img 579)"    "install.sh --only tools"
chk google-adk   "2.2.0"  "$(ver google-adk)"                                                         exact  "2.2.0"            "install.sh --only python"
chk agents-cli   "1.3.1"  "$(ver google-agents-cli)"                                                  exact  "1.3.1"            "install.sh --only python"
chk google-genai "2.16.0" "$(ver google-genai)"                                                       exact  "2.16.0"           "install.sh --only python"
# litellm and an OpenAI client used to arrive via google-cloud-aiplatform[evaluation].
# Nothing in these labs uses them, so they are excluded - assert they stay excluded,
# which also catches an install that forgot --no-deps and let the resolver re-add them.
chk no-vendor-sdk "0"      "$("$PY" -c "import importlib.metadata as m;print(sum(1 for d in m.distributions() if (d.metadata['Name'] or '').lower() in ('litellm','openai','tiktoken','tokenizers','cdp')))" 2>/dev/null)" exact "0 pkgs" "install.sh --only python --force"
chk packages     "120"    "$("$PY" -c "import importlib.metadata as m;print(sum(1 for d in m.distributions() if (d.metadata['Name'] or '') not in ('pip','setuptools','wheel')))" 2>/dev/null)" exact "120" "install.sh --only python"
chk sessions     "3"      "$(ls -d "$LAB_ROOT"/Desktop/Session[123]/.agents/skills 2>/dev/null | wc -l | tr -d ' ')" exact "3"  "install.sh --only sessions"

# The lab skills ship separately from this repository. If none are installed, these two
# checks are not applicable - they must not fail a software-only setup.
if [ -n "$(ls -A "$SESSION/.agents/skills" 2>/dev/null)" ]; then
  chk lab-skill    "ok"   "$([ -f "$SESSION/.agents/skills/novasmart-governance-lab/SKILL.md" ] && echo ok)" exact "ok" "install.sh --only sessions --skills-src DIR"
  # component-aware: a bare /config also matches /configure in documentation URLs
  chk config-paths "0"    "$(grep -rlE '(^|[[:space:]`\"(])/config([^a-zA-Z]|$)' "$SESSION/.agents/skills" 2>/dev/null | wc -l | tr -d ' ')" exact "0 files" "install.sh --only skills --skills-src DIR"
else
  ROWS+=("lab-skills|not installed|n/a|SKIP|see README - skills are distributed separately")
fi

total=$((pass+drift+missing))
code=0; [ "$drift" -gt 0 ] && code=1; [ "$missing" -gt 0 ] && code=2

if [ "$JSON" = 1 ]; then
  printf '{"pass":%d,"drift":%d,"missing":%d,"total":%d,"exit":%d,"checks":[' "$pass" "$drift" "$missing" "$total" "$code"
  for i in "${!ROWS[@]}"; do
    IFS='|' read -r n d f s hint <<< "${ROWS[$i]}"
    [ "$i" -gt 0 ] && printf ','
    printf '{"name":"%s","needed":"%s","found":"%s","status":"%s","fix":"%s"}' "$n" "$d" "$f" "$s" "$hint"
  done
  printf ']}\n'
else
  printf "  %-16s %-18s %-22s %s\n" CHECK NEEDED FOUND STATUS
  printf '  '; printf '%.0s-' {1..66}; echo
  for r in "${ROWS[@]}"; do
    IFS='|' read -r n d f s hint <<< "$r"
    printf "  %-16s %-18s %-22s %s\n" "$n" "$d" "$f" "$s"
  done
  echo
  [ -f "$REPO_DIR/skills/PROVENANCE.txt" ] && echo "  skills     : $(head -1 "$REPO_DIR/skills/PROVENANCE.txt")"
  echo "  in Session1: $(ls -1 "$SESSION/.agents/skills" 2>/dev/null | tr '\n' ' ')"
  echo "  scorecard  : ${NOVASMART_SCORECARD_HOME:-UNSET — set it, see runbook 4.4}"
  echo "  gcp account: $(gcloud config get-value account 2>/dev/null) (must be the lab account, not personal or work)"
  echo "  gcp project: $(gcloud config get-value project 2>/dev/null)"
  echo "  adc        : $([ -f "$HOME/.config/gcloud/application_default_credentials.json" ] && echo present || echo MISSING)"
  echo
  echo "  $pass of $total checks OK"
  if [ "$READINESS" = 1 ]; then
    echo
    echo "  READINESS REPORT"
    printf '  '; printf '%.0s=' {1..66}; echo
    sw="not ready"; est="not ready"; auth="not ready"
    [ "$code" = 0 ] && sw="ready"
    [ -f "$SESSION/.agents/skills/novasmart-governance-lab/SKILL.md" ] && est="installed"
    [ -f "$HOME/.config/gcloud/application_default_credentials.json" ] \
      && [ -n "$(gcloud config get-value project 2>/dev/null)" ] && auth="signed in"
    printf "  %-34s %s\n" "software toolchain"        "$sw"
    printf "  %-34s %s\n" "lab skills in Session1"    "$est"
    printf "  %-34s %s\n" "google cloud sign-in"      "$auth"
    printf "  %-34s %s\n" "antigravity IDE"           "check by hand - open it"
    printf "  %-34s %s\n" "cloud project provisioned" "ask your lab administrator"
    echo
    if [ "$sw" = ready ] && [ "$est" = installed ] && [ "$auth" = "signed in" ]; then
      echo "  Your laptop is ready. Open $SESSION in Antigravity and begin."
    else
      echo "  Still to do:"
      [ "$sw"   != ready ]       && echo "    - fix the failing checks above (bash setup/verify.sh --fix-hints)"
      [ "$est"  != installed ]   && echo "    - install the lab skills: bash setup/install.sh --only sessions"
      [ "$auth" != "signed in" ] && { echo "    - gcloud auth login && gcloud auth application-default login"
                                      echo "      then: gcloud config set project PROJECT_ID"
                                      echo "            gcloud auth application-default set-quota-project PROJECT_ID"; }
      echo "    - open Antigravity and sign in with 'Use Google Cloud project instead'"
      echo "    - confirm with your lab administrator that the cloud estate is provisioned"
    fi
  fi
  if [ "$HINTS" = 1 ] && [ "$code" != 0 ]; then
    echo; echo "  how to fix:"
    for r in "${ROWS[@]}"; do
      IFS='|' read -r n d f s hint <<< "$r"
      [ "$s" != OK ] && [ -n "$hint" ] && printf "    %-16s %s\n" "$n" "$hint"
    done
  fi
fi
exit "$code"
