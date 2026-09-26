#!/usr/bin/env bash
# Build with Gemini lab - laptop setup for Track 2 and Track 3.
# Track 2: the NovaSmart governance lab. Track 3: the agent-first app starter kit.
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
# ALL_STEPS is the registry of every step this script implements. The two lists below
# decide which of them a track actually runs, and in what order. --only validates
# against ALL_STEPS, so every registered step stays individually runnable.
ALL_STEPS=(tools python skills sessions register starterkit)
TRACK2_STEPS=(tools python skills sessions register)
TRACK3_STEPS=(tools python starterkit register)
TRACK_STEPS=()

# Track 3 works out of a starter kit that lives in a separate community repository.
# It is not maintained here and it is not an official Google product. Point --kit-url
# at a fork or an offline mirror if you do not want to fetch the upstream copy.
KIT_URL="${KIT_URL:-https://github.com/cszhu/build-with-gemini}"
KIT_DIR="${KIT_DIR:-}"                 # resolved after the flags: it depends on --root

DRY=0; ONLY=""; ASSUME_YES=0; FORCE=0; WITH_EXTRAS=0; SKIP_PREFLIGHT=0
TRACK="${BWG_TRACK:-}"
LOG="$LAB_HOME/install.log"

usage() { sed -n '2,4p' "$0"; cat <<EOF

Usage: install.sh [options]
  --track {2,3}      which track to set up. Without it the script asks, and falls
                     back to Track 2 when there is no terminal to ask on
  --dry-run          print every command, change nothing (never asks for a track)
  --only STEP        run one step: ${ALL_STEPS[*]}
                     --only starterkit implies --track 3 when no track is given
  --with-extras      also install ffmpeg, VS Code, Playwright's browser
  --force            overwrite an existing venv or session folders
  --yes              do not prompt (does NOT override a preflight NO-GO)
  --skip-preflight   do not run preflight first
  --root DIR         parent of Desktop/SessionN (default: \$HOME)
  --skills-src DIR   directory holding the lab skills (not shipped in this repo)
  --kit-dir DIR      Track 3 only: where to clone the starter kit
                     (default: \$LAB_ROOT/Desktop/build-with-gemini)
  --kit-url URL      Track 3 only: the starter kit repository, a community repo
                     (default: $KIT_URL)
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
    --track) TRACK="${2:?--track needs 2 or 3}"; shift ;;
    --kit-dir) KIT_DIR="${2:?--kit-dir needs a directory}"; shift ;;
    --kit-url) KIT_URL="${2:?--kit-url needs a URL}"; shift ;;
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

# ---------- which track ----------
# The track decides which steps run, so it has to be settled before anything else.
# Three ways to say it, in order: --track, then the question below, then Track 2.
#
# A dry run NEVER asks. It exists to be piped, read and diffed, so it has to print the
# same bytes whether or not a human is watching, and it must not block a CI job that
# has no terminal. For the same reason the "we picked one for you" notice goes to
# stderr: it belongs on the operator's screen, not in the transcript of the commands.
# --only starterkit is self-identifying, so it does not need to be asked about.
if [ -z "$TRACK" ] && [ "$ONLY" = starterkit ]; then TRACK=3; fi
if [ -z "$TRACK" ]; then
  if [ "$DRY" = 0 ] && [ -t 0 ]; then
    say "Which track are you doing?"
    info "2) Track 2 - NovaSmart governance lab, three session folders on your Desktop"
    info "3) Track 3 - agent-first app, built from the community Track 3 starter kit"
    printf '    Track [2] '; read -r a
    case "$a" in
      3) TRACK=3 ;;
      ""|2) TRACK=2 ;;
      *) echo "not a track: $a (use 2 or 3)" >&2; exit 64 ;;
    esac
  else
    TRACK=2
    warn "no --track given and no terminal to ask on - setting up Track 2. Pass --track 3 for the Track 3 starter kit."
  fi
fi
case "$TRACK" in
  2) TRACK_STEPS=("${TRACK2_STEPS[@]}") ;;
  3) TRACK_STEPS=("${TRACK3_STEPS[@]}") ;;
  *) echo "unknown track: $TRACK (use 2 or 3)" >&2; usage >&2; exit 64 ;;
esac
[ -n "$KIT_DIR" ] || KIT_DIR="$LAB_ROOT/Desktop/build-with-gemini"

# Step headings count themselves against the selected track's list, so Track 2 still
# reads "Step 3/5" and Track 3 reads "Step 3/4" without either number being written
# down anywhere. A step run outside its track (--only) prints its title with no number.
heading() { # step-name  title
  local name=$1 title=$2 i=1 s
  for s in ${TRACK_STEPS[@]+"${TRACK_STEPS[@]}"}; do
    [ "$s" = "$name" ] && { say "Step $i/${#TRACK_STEPS[@]}  $title"; return 0; }
    i=$((i+1))
  done
  say "$title"
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
  heading tools "Install the tools  ($OS/$ARCH)"
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
    # Track 3 only. gh is not in the Debian or Ubuntu archives at a usable version, so
    # it comes from GitHub's own apt repository, the same shape as gcloud above.
    # See the note above step_starterkit for why this is installed here.
    local pkgs=(google-cloud-cli nodejs)
    if [ "$TRACK" = 3 ]; then
      if ! need gh; then
        run sudo install -m 0755 -d /usr/share/keyrings
        run bash -c 'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg status=none'
        run sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        run bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null'
      fi
      pkgs+=(gh)
    fi
    run sudo DEBIAN_FRONTEND=noninteractive apt-get update
    run sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
  fi
  need uv || run bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  export PATH="$HOME/.local/bin:$PATH"
  run uv python install "$PY_VERSION"
}

step_python() {
  heading python "The Python environment"
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

step_skills() {
  heading skills "Prepare the lab skills"
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
  heading sessions "Create the session folders"
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

# Track 3 only. Everything this step touches belongs to a community repository:
# github.com/cszhu/build-with-gemini. That repo is not maintained here, it is not an
# official Google product, and its contents can change without notice. This step
# clones it and reports what arrived; it does not vendor or rewrite any of it.
#
# There is no "register the kit's skills" command to run. Antigravity reads the
# .agents/ folder of the workspace you open, so cloning the kit IS the registration.
# The kit's own troubleshooting skill talks about `agents-cli setup`, but that is a
# different thing: it installs the global google-agents-cli-* lifecycle skills, which
# step_register already does for both tracks.
#
# gh is installed in step_tools rather than left to the kit. The kit's publish script
# does fetch gh on its own, unauthenticated, into ~/.local/bin, at the very end of the
# lab, when a room full of people is on the same network and short of time. Installing
# it up front moves that download off the critical path and puts gh on PATH properly.
# The kit's fetch is guarded by `command -v gh`, so doing it here makes that a no-op.
step_starterkit() {
  heading starterkit "Fetch the Track 3 starter kit"
  info "source: $KIT_URL"
  info "this is a community repository - it is not maintained by this repo and not an official Google product"
  if [ -d "$KIT_DIR/.git" ] && [ "$FORCE" != 1 ]; then
    info "starter kit already at $KIT_DIR — reusing it (--force to move it aside and re-clone)"
  else
    # Never delete this directory. Once the lab starts it holds the participant's own
    # work, so --force moves it out of the way instead of removing it.
    if [ -e "$KIT_DIR" ]; then
      local aside; aside="$KIT_DIR.superseded.$(date +%Y%m%d%H%M%S)"
      info "$KIT_DIR exists and is not a clone - moving it aside, nothing is deleted"
      run mv "$KIT_DIR" "$aside"
    fi
    run mkdir -p "$(dirname "$KIT_DIR")"
    run git clone --depth 1 "$KIT_URL" "$KIT_DIR"
  fi
  if [ "$DRY" = 1 ]; then
    info "the kit ships its skills under .agents/skills/ - Antigravity loads them when you open the folder"
  elif [ -d "$KIT_DIR/.agents/skills" ]; then
    local n; n="$(find "$KIT_DIR/.agents/skills" -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
    info "$n starter-kit skill(s) under $KIT_DIR/.agents/skills"
    info "no registration needed - Antigravity loads them when you open that folder"
  else
    warn "no .agents/skills in $KIT_DIR - the kit layout may have changed, check $KIT_URL"
  fi
  if need gh; then info "gh: $(gh --version 2>/dev/null | awk 'NR==1{print $3}')"
  else warn "gh is missing - the kit's publish-to-github skill will download it into ~/.local/bin at the end of the lab"
  fi
  info "Track 3 working folder: $KIT_DIR"
}

step_register() {
  heading register "Register the skills"
  local py="$LAB_HOME/.venv/bin"
  # Track 2 only: the governance lab's scorecard script is what reads this.
  if [ "$TRACK" = 2 ]; then
    grep -q NOVASMART_SCORECARD_HOME "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null \
      || info "add to your shell profile:  export NOVASMART_SCORECARD_HOME=\"$LAB_ROOT\""
  fi
  # This registers the google-agents-cli-* lifecycle skills (scaffold, deploy and the
  # rest) with Antigravity. Both tracks need them. It does NOT register the skills that
  # ship inside a repository's own .agents/ folder: Antigravity reads those itself when
  # you open the folder, so Track 3's starter-kit skills need nothing from this step.
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
  echo "  install.sh is about to set up Track $TRACK and change this machine. It will:"
  echo "    - install packages with $PKG (this needs sudo on Linux)"
  echo "    - create $LAB_HOME and a Python 3.14 virtual environment there"
  if [ "$TRACK" = 3 ]; then
    echo "    - install the GitHub CLI (gh), which Track 3 needs to publish your project"
    echo "    - clone the community Track 3 starter kit into $KIT_DIR"
    echo "      from $KIT_URL, which this repository does not maintain"
  else
    echo "    - create session folders under $LAB_ROOT/Desktop/"
  fi
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
  local steps=("${TRACK_STEPS[@]}")
  [ -z "$ONLY" ] && gate
  if [ -n "$ONLY" ]; then
    # shellcheck disable=SC2076
    [[ " ${ALL_STEPS[*]} " == *" $ONLY "* ]] || { echo "unknown step: $ONLY" >&2; exit 64; }
    steps=("$ONLY")
  fi
  for s in "${steps[@]}"; do CURRENT_STEP="$s"; "step_$s"; done
  local vflag=""
  [ "$TRACK" = 3 ] && vflag=" --track 3"
  say "Done. Now run:  bash $SCRIPT_DIR/verify.sh --readiness$vflag"
  if [ "$TRACK" = 3 ]; then
    info "Then open $KIT_DIR in Antigravity."
  else
    info "Then open $LAB_ROOT/Desktop/Session1 in Antigravity."
  fi
}
main
