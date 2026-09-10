#!/usr/bin/env bash
# NovaSmart lab — laptop setup.
# Idempotent: safe to re-run. Nothing here is destructive without --force.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"    # this script lives in <repo>/setup/

# Lab skills. Bundled in this repo under skills/, so no flag is needed. Override with
# --skills-src DIR to use a copy from somewhere else.
LAB_SKILLS_SRC="${LAB_SKILLS_SRC:-}"
if [ -z "$LAB_SKILLS_SRC" ] && [ -d "$REPO_DIR/skills" ]; then LAB_SKILLS_SRC="$REPO_DIR/skills"; fi
LAB_HOME="${LAB_HOME:-$HOME/novasmart-lab}"
LAB_ROOT="${LAB_ROOT:-$HOME}"          # session folders live at $LAB_ROOT/Desktop/SessionN
PY_VERSION="3.14"
SESSIONS=(Session1 Session2 Session3)
LAB_SKILLS=(novasmart-governance-lab)
DEMO_SKILLS=(build-demo bwgtrack2-demo-build)
ALL_STEPS=(tools python agy skills sessions register)

DRY=0; ONLY=""; ASSUME_YES=0; FORCE=0; WITH_EXTRAS=0; SKIP_PREFLIGHT=0
LOG="$LAB_HOME/install.log"

usage() { sed -n '2,4p' "$0"; cat <<EOF

Usage: install.sh [options]
  --dry-run          print every command, change nothing
  --only STEP        run one step: ${ALL_STEPS[*]}
  --with-extras      also install ffmpeg, VS Code, Playwright's browser
  --force            overwrite an existing venv or session folders
  --yes              do not prompt (does NOT override a preflight NO-GO)
  --skip-preflight   do not run preflight first
  --root DIR         parent of Desktop/SessionN (default: \$HOME)
  --skills-src DIR   directory holding the lab skills (not shipped in this repo)
  -h, --help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --only) ONLY="${2:?--only needs a step}"; shift ;;
    --with-extras) WITH_EXTRAS=1 ;;
    --force) FORCE=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --skip-preflight) SKIP_PREFLIGHT=1 ;;
    --root) LAB_ROOT="${2:?--root needs a directory}"; shift ;;
    --skills-src) LAB_SKILLS_SRC="${2:?--skills-src needs a directory}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
  shift
done

on_err() {
  local rc=$?
  printf '\n\033[31mfailed\033[0m during step "%s" (exit %s)\n' "${CURRENT_STEP:-?}" "$rc" >&2
  printf 'retry just this step with:  bash %s --only %s\n' "$0" "${CURRENT_STEP:-all}" >&2
  exit "$rc"
}
trap on_err ERR

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    \033[33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\n\033[31mfailed:\033[0m %s\n' "$*" >&2
         printf 'retry just this step with:  %s --only %s\n' "$0" "${CURRENT_STEP:-all}" >&2
         exit 1; }

run() {
  if [ "$DRY" = 1 ]; then printf '    $ %s\n' "$*"; return 0; fi
  printf '    $ %s\n' "$*"
  [ -d "$LAB_HOME" ] && printf '%s | %s\n' "$(date -Is)" "$*" >> "$LOG" 2>/dev/null || true
  "$@"
}

confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  [ "$DRY" = 1 ] && return 0
  printf '    %s [y/N] ' "$1"; read -r a; [ "$a" = y ] || [ "$a" = Y ]
}

# ---------- platform detection ----------
OS=""; PKG=""
case "$(uname -s)" in
  Darwin) OS=macos; PKG=brew ;;
  Linux)  OS=linux; PKG=apt
          grep -qi microsoft /proc/version 2>/dev/null && OS=wsl2 ;;
  *) die "unsupported OS: $(uname -s). Native Windows is unsupported - use WSL2. See TROUBLESHOOTING.md" ;;
esac
ARCH="$(uname -m)"
IS_INTEL_MAC=0
[ "$OS" = macos ] && [ "$ARCH" = x86_64 ] && IS_INTEL_MAC=1

need() { command -v "$1" >/dev/null 2>&1; }

# ---------- steps ----------
step_tools() {
  say "Step 1/6  Install the tools  ($OS/$ARCH)"
  if [ "$PKG" = brew ]; then
    need brew || die "Homebrew is required on macOS: https://brew.sh"
    need git    || run brew install git
    need gcloud || run brew install --cask gcloud-cli
    if ! need node; then
      run brew install node@24
      local nodebin; nodebin="$(brew --prefix)/opt/node@24/bin"
      export PATH="$nodebin:$PATH"
      info "node@24 is keg-only. Added to PATH for this run; make it permanent with:"
      info "  echo 'export PATH=\"$nodebin:\$PATH\"' >> ~/.zshrc"
    fi
    if [ "$IS_INTEL_MAC" = 1 ] && ! need cargo; then
      warn "Intel Mac: 'cryptography' has no Intel wheel and must be compiled."
      confirm "Install Rust and Xcode command line tools now?" \
        && { run xcode-select --install || true; run brew install rust; } \
        || warn "Skipping. The python step will fail without them."
    fi
  else
    # DEBIAN_FRONTEND must be passed THROUGH sudo: sudo's env_reset strips it, and
    # without it tzdata's postinst opens an interactive debconf prompt that hangs the
    # install forever with no output. Found by the container journey test.
    info "apt steps need sudo."
    run sudo DEBIAN_FRONTEND=noninteractive apt-get update
    run sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget gnupg ca-certificates apt-transport-https git build-essential
    if ! need gcloud; then
      run sudo install -m 0755 -d /usr/share/keyrings
      run bash -c 'curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg'
      run bash -c 'echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null'
    fi
    need node || run bash -c 'curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E DEBIAN_FRONTEND=noninteractive bash -'
    run sudo DEBIAN_FRONTEND=noninteractive apt-get update
    run sudo DEBIAN_FRONTEND=noninteractive apt-get install -y google-cloud-cli nodejs
  fi
  need uv || run bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  export PATH="$HOME/.local/bin:$PATH"
  run uv python install "$PY_VERSION"
}

step_python() {
  say "Step 2/6  The Python environment"
  run mkdir -p "$LAB_HOME"
  if [ -d "$LAB_HOME/.venv" ] && [ "$FORCE" != 1 ]; then
    info "venv exists — reusing it (--force to rebuild)"
  else
    [ -d "$LAB_HOME/.venv" ] && run rm -rf "${LAB_HOME:?}/.venv"
    run uv venv --seed --python "$PY_VERSION" "$LAB_HOME/.venv"
  fi
  local lock="$SCRIPT_DIR/requirements-lock.txt"
  [ -f "$lock" ] || die "requirements-lock.txt not found next to this script ($SCRIPT_DIR)"
  info "installing $(grep -c '==' "$lock") pinned packages (~230 MB)"
  # --no-deps is deliberate: the lockfile is the COMPLETE resolved set. Without it the
  # resolver re-adds packages we removed on purpose (google-agents-cli hard-requires
  # google-cloud-aiplatform[evaluation], whose extra drags in litellm and an OpenAI
  # client), and at unpinned newer versions.
  run env VIRTUAL_ENV="$LAB_HOME/.venv" uv pip install --no-deps -r "$lock"
  if [ "$WITH_EXTRAS" = 1 ]; then
    info "installing Playwright's browser (~170 MB)"
    run "$LAB_HOME/.venv/bin/playwright" install chromium
    if [ "$PKG" = brew ]; then
      need ffmpeg || run brew install ffmpeg
      need code   || run brew install --cask visual-studio-code
    else
      run sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ffmpeg
      if ! need code; then
        run bash -c 'wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg'
        run bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null'
        run sudo DEBIAN_FRONTEND=noninteractive apt-get update && run sudo DEBIAN_FRONTEND=noninteractive apt-get install -y code
      fi
    fi
  fi
}

step_agy() {
  say "Step 3/6  The agy CLI"
  if need agy; then info "agy already installed: $(agy --version 2>/dev/null || echo '?')"; return 0; fi
  run bash -c 'curl -fsSL https://antigravity.google/cli/install.sh | bash'
  export PATH="$HOME/.local/bin:$PATH"
}

step_skills() {
  say "Step 4/6  Prepare the lab skills"
  if [ -z "$LAB_SKILLS_SRC" ]; then
    info "no skills/ directory in this repo and no --skills-src given - skipping."
    info "Re-run with:  install.sh --only skills --skills-src /path/to/skills"
    return 0
  fi
  [ -d "$LAB_SKILLS_SRC" ] || die "--skills-src not a directory: $LAB_SKILLS_SRC"
  [ -f "$LAB_SKILLS_SRC/PROVENANCE.txt" ] && info "skills revision: $(sed -n 2p "$LAB_SKILLS_SRC/PROVENANCE.txt")"

  # The bundled skills are published already portable, so this is normally a no-op.
  # A copy taken straight from the lab VM still hardcodes /config as the home directory.
  # `|| true` matters: grep exits 1 when it matches nothing, and pipefail would kill us.
  local hits
  hits="$(grep -rlE '(^|[[:space:]`\"(])/config([^a-zA-Z]|$)' "$LAB_SKILLS_SRC" 2>/dev/null || true)"
  if [ -z "$hits" ]; then
    info "skills are already path-portable - nothing to rewrite"
    return 0
  fi
  local n; n="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
  info "rewriting $n file(s) that hardcode the VM path /config"
  if [ "$DRY" = 1 ]; then
    printf '    $ sed -i.bak "s#/config#%s#g"  (%s files)\n' "$LAB_ROOT" "$n"
    return 0
  fi
  # Rewrite /config only where it STARTS an absolute path. Two narrower rules were
  # tried and both corrupted shipped text: a bare replace mangles /configure inside a
  # documentation URL, and a component-only guard still mangles deployment/config.
  printf '%s\n' "$hits" | while read -r f; do
    [ -n "$f" ] || continue
    sed -i.bak -E "s#(^|[[:space:]\`\"(])/config([^a-zA-Z]|\$)#\\1$LAB_ROOT\\2#g" "$f"; rm -f "$f.bak"
  done
  # Use the same component-aware pattern as the rewrite: a bare grep for /config
  # also matches /configure inside documentation URLs, which is legitimate.
  if grep -rqE '(^|[[:space:]`\"(])/config([^a-zA-Z]|$)' "$LAB_SKILLS_SRC" 2>/dev/null; then
    die "rewrite incomplete - /config still present in $LAB_SKILLS_SRC"
  fi
  return 0
}

step_sessions() {
  say "Step 5/6  Create the session folders"
  for s in "${SESSIONS[@]}"; do
    run mkdir -p "$LAB_ROOT/Desktop/$s/.agents/skills"
  done
  if [ -z "$LAB_SKILLS_SRC" ]; then
    info "folders created empty - add the lab skills to each .agents/skills/ when you receive them"
    return 0
  fi
  local src="$LAB_SKILLS_SRC"
  for s in "${SESSIONS[@]}"; do
    local dest="$LAB_ROOT/Desktop/$s/.agents/skills"
    for k in "${LAB_SKILLS[@]}"; do
      if [ -d "$src/$k" ]; then
        [ -e "$dest/$k" ] && run rm -rf "${dest:?}/$k"
        run cp -r "$src/$k" "$dest/"
      fi
    done
    # build-demo is a catalog dir; its children must land flat, one level deep.
    for k in "${DEMO_SKILLS[@]}"; do
      if [ -f "$src/build-demo/$k/SKILL.md" ]; then
        [ -e "$dest/$k" ] && run rm -rf "${dest:?}/$k"
        run cp -r "$src/build-demo/$k" "$dest/"
      fi
    done
  done
  info "sessions ready under $LAB_ROOT/Desktop/"
}

step_register() {
  say "Step 6/6  Register the skills"
  local py="$LAB_HOME/.venv/bin"
  grep -q NOVASMART_SCORECARD_HOME "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null \
    || info "add to your shell profile:  export NOVASMART_SCORECARD_HOME=\"$LAB_ROOT\""
  run "$py/agents-cli" setup  || warn "agents-cli setup failed — non-fatal, the assistant can self-register"
  run "$py/agents-cli" update || warn "agents-cli update failed — a version-mismatch warning may appear"
  run "$py/agents-cli" info   || true
}

# ---------- driver ----------
CURRENT_STEP=""

# Nothing is installed until preflight has run and a human has said yes.
# --skip-preflight exists for re-runs and repairs; --yes alone does NOT bypass a NO-GO.
gate() {
  [ "$DRY" = 1 ] && return 0
  [ "$SKIP_PREFLIGHT" = 1 ] && { info "preflight skipped (--skip-preflight)"; return 0; }
  if [ ! -x "$SCRIPT_DIR/preflight.sh" ]; then
    warn "preflight.sh not found - continuing without it"; return 0
  fi
  # `cmd; rc=$?` is NOT set -e safe: the non-zero exit fires the ERR trap before the
  # assignment runs. preflight returns 1 for GO WITH CAVEATS, which is the common case,
  # so this killed the installer on most real machines.
  local pf=0
  bash "$SCRIPT_DIR/preflight.sh" || pf=$?
  case "$pf" in
    0) say "Preflight: GO" ;;
    1) say "Preflight: GO WITH CAVEATS" ;;
    2) printf '\n\033[31mPreflight says NO-GO.\033[0m This laptop is missing something it cannot do without.\n' >&2
       printf 'Fix the blocking items above, or use the provided lab VM.\n' >&2
       printf 'If you believe this is wrong, re-run with --skip-preflight.\n' >&2
       exit 2 ;;
    *) warn "preflight could not assess this machine (exit $pf)" ;;
  esac
  echo
  echo "  install.sh is about to change this machine. It will:"
  echo "    - install packages with $PKG (this needs sudo on Linux)"
  echo "    - create $LAB_HOME and a Python 3.14 virtual environment there"
  echo "    - create session folders under $LAB_ROOT/Desktop/"
  echo "    - append to your shell profile"
  echo "  Nothing outside those paths is touched. Re-runnable and idempotent."
  echo
  if [ "$ASSUME_YES" = 1 ]; then
    info "--yes given, proceeding without asking"
  else
    printf '  Continue? [y/N] '; read -r a
    case "$a" in y|Y) ;; *) echo "  Stopped. Nothing was changed."; exit 0 ;; esac
  fi
}

main() {
  if [ "$DRY" = 1 ]; then say "DRY RUN - nothing will be changed"
  else mkdir -p "$LAB_HOME" 2>/dev/null || true; fi
  local steps=("${ALL_STEPS[@]}")
  [ -z "$ONLY" ] && gate
  if [ -n "$ONLY" ]; then
    # shellcheck disable=SC2076
    [[ " ${ALL_STEPS[*]} " == *" $ONLY "* ]] || { echo "unknown step: $ONLY" >&2; exit 64; }
    steps=("$ONLY")
  fi
  for s in "${steps[@]}"; do CURRENT_STEP="$s"; "step_$s"; done
  say "Done. Now run:  bash $SCRIPT_DIR/verify.sh --readiness"
  info "Then open $LAB_ROOT/Desktop/Session1 in Antigravity."
}
main
