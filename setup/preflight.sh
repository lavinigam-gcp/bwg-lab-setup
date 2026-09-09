#!/usr/bin/env bash
# Can this laptop run the lab? Run this FIRST, before install.sh.
# Produces a pre-setup report card and a GO / GO WITH CAVEATS / NO-GO verdict.
# Exit: 0 GO · 1 GO WITH CAVEATS · 2 NO-GO · 3 could not assess
# Read-only: installs nothing, changes nothing.
set -uo pipefail

JSON=0
for a in ${@+"$@"}; do case "$a" in
  --json) JSON=1 ;;
  -h|--help) sed -n '2,6p' "$0"; echo "Usage: preflight.sh [--json]"; exit 0 ;;
esac; done

ROWS=(); FAIL=0; WARN=0; OK=0
add() { # name  status(OK|WARN|FAIL)  found  requirement  advice
  ROWS+=("$1|$2|$3|$4|$5")
  case "$2" in OK) OK=$((OK+1));; WARN) WARN=$((WARN+1));; FAIL) FAIL=$((FAIL+1));; esac
}

# ---------- platform ----------
KERNEL="$(uname -s)"; ARCH="$(uname -m)"; OSNAME="?"; OSVER="0"; PLAT="?"
case "$KERNEL" in
  Darwin)
    PLAT=macos; OSNAME="macOS"; OSVER="$(sw_vers -productVersion 2>/dev/null || echo 0)"
    # uname -m lies under Rosetta; this pierces it.
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = 1 ]; then ARCH=arm64; fi
    ;;
  Linux)
    PLAT=linux
    # shellcheck disable=SC1091
    [ -r /etc/os-release ] && . /etc/os-release && OSNAME="${NAME:-Linux}" && OSVER="${VERSION_ID:-0}"
    grep -qi microsoft /proc/version 2>/dev/null && PLAT=wsl2
    ;;
  *) PLAT=unsupported; OSNAME="$KERNEL" ;;
esac

verge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n | awk 'NR==1')" = "$2" ]; }

if [ "$PLAT" = unsupported ]; then
  add "operating system" FAIL "$OSNAME" "macOS, Linux, or Windows+WSL2" \
      "Native Windows cannot run this: a required package (uvloop) has no Windows build. Install WSL2, or use the lab VM."
else
  case "$PLAT" in
    macos) verge "$OSVER" 13 && add "operating system" OK "macOS $OSVER" "macOS 13+" "" \
                              || add "operating system" FAIL "macOS $OSVER" "macOS 13+" "Chrome and the toolchain need macOS 13 Ventura or newer. Upgrade, or use the lab VM." ;;
    linux)
      # Test the actual requirement rather than the release number. Rolling releases
      # legitimately have no VERSION_ID, and Antigravity's real floor is glibc 2.28.
      # awk, not `| head -1`: head closes the pipe early, ldd takes SIGPIPE, and with
      # pipefail the whole substitution fails intermittently and reports glibc 0.
      GLIBC="$(ldd --version 2>/dev/null | awk 'NR==1{print $NF}')"
      [ -n "$GLIBC" ] || GLIBC=0
      if verge "$GLIBC" 2.28; then
        add "operating system" OK "$OSNAME ${OSVER#0} (glibc $GLIBC)" "glibc 2.28+" ""
      else
        add "operating system" FAIL "$OSNAME ${OSVER#0} (glibc $GLIBC)" "glibc 2.28+" \
          "Antigravity requires glibc 2.28 or newer and will not launch here. Upgrade the distribution, or use the lab VM."
      fi ;;
    wsl2)  add "operating system" OK "$OSNAME $OSVER (WSL2)" "WSL2 with WSLg" \
               "" ;;
  esac
fi

case "$ARCH" in
  x86_64|amd64|arm64|aarch64) add "cpu architecture" OK "$ARCH" "x86_64 or arm64" "" ;;
  *) add "cpu architecture" FAIL "$ARCH" "x86_64 or arm64" "No builds exist for this architecture. Use the lab VM." ;;
esac

# ---------- capacity ----------
CORES="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"
if   [ "$CORES" -ge 4 ] 2>/dev/null; then add "cpu cores" OK "$CORES" "4+" ""
elif [ "$CORES" -ge 2 ] 2>/dev/null; then add "cpu cores" WARN "$CORES" "4+" "2 cores works but installs and the IDE will feel slow."
else add "cpu cores" FAIL "${CORES:-unknown}" "4+" "Too few cores for the IDE plus a browser. Use the lab VM."; fi

RAM_GIB=0
case "$PLAT" in
  macos) B="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"; RAM_GIB=$(( B / 1073741824 )) ;;
  *)     K="$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)"; RAM_GIB=$(( K / 1048576 )) ;;
esac
# Linux reports usable RAM (~6% below nominal), macOS reports nominal. Gate below the nominal figure.
if   [ "$RAM_GIB" -ge 15 ]; then add "memory" OK "${RAM_GIB} GiB" "16 GB recommended" ""
elif [ "$RAM_GIB" -ge 7 ];  then add "memory" WARN "${RAM_GIB} GiB" "16 GB recommended" "8 GB is the floor. Close other applications during the lab, or expect swapping."
else add "memory" FAIL "${RAM_GIB} GiB" "8 GB minimum" "Not enough memory to run the IDE, a browser and the toolchain. Use the lab VM."; fi
[ "$PLAT" = wsl2 ] && add "wsl memory note" WARN "${RAM_GIB} GiB visible" "host has more" \
  "WSL2 defaults to half the host's RAM. Raise it in .wslconfig if this is tight."

DISK_GIB="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2{print int($4/1048576)}')"
DISK_GIB="${DISK_GIB:-0}"
if   [ "$DISK_GIB" -ge 15 ]; then add "free disk" OK "${DISK_GIB} GiB" "15 GiB" ""
elif [ "$DISK_GIB" -ge 10 ]; then add "free disk" WARN "${DISK_GIB} GiB" "15 GiB" "Tight. Skip the optional extras, or free up space first."
else add "free disk" FAIL "${DISK_GIB} GiB" "15 GiB" "Not enough free space. Free some up, or use the lab VM."; fi
if [ "$PLAT" = wsl2 ] && [ -d /mnt/c ]; then
  CGIB="$(df -Pk /mnt/c 2>/dev/null | awk 'NR==2{print int($4/1048576)}')"
  [ -n "${CGIB:-}" ] && [ "$CGIB" -lt 15 ] && add "windows C: space" FAIL "${CGIB} GiB" "15 GiB" \
    "WSL2 reports a large virtual disk, but the real space is on C:. Free space on Windows first."
fi

# ---------- prerequisites ----------
for t in git curl; do
  if command -v "$t" >/dev/null 2>&1; then add "$t" OK "present" "required" ""
  else add "$t" FAIL "missing" "required" "Install $t before continuing."; fi
done
if command -v python3 >/dev/null 2>&1; then add "python3" OK "$(python3 -V 2>&1 | awk '{print $2}')" "any (3.14 installed later)" ""
else add "python3" WARN "missing" "any" "Not fatal: uv installs its own Python 3.14."; fi
if [ "$PLAT" = macos ]; then
  command -v brew >/dev/null 2>&1 && add "homebrew" OK "present" "required on macOS" "" \
    || add "homebrew" FAIL "missing" "required on macOS" "Install Homebrew first: https://brew.sh"
fi
if command -v sudo >/dev/null 2>&1 && [ "$PLAT" != macos ]; then
  sudo -n true 2>/dev/null && add "sudo" OK "no password needed" "needed for apt" "" \
    || add "sudo" WARN "will prompt" "needed for apt" "You will be asked for your password during the tool step."
fi

# ---------- connectivity ----------
probe() { # label url
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 12 -L "$2" 2>/dev/null || echo 000)"
  if [ "$code" = 000 ]; then add "$1" FAIL "unreachable" "reachable" "Blocked or offline. Check your network, VPN or firewall."
  else add "$1" OK "HTTP $code" "reachable" ""; fi
}
probe "github.com"        "https://github.com"
probe "pypi.org"          "https://pypi.org/simple/"
probe "storage.googleapis.com" "https://storage.googleapis.com"
probe "antigravity.google" "https://antigravity.google/download"
probe "googleapis.com"    "https://oauth2.googleapis.com"
[ "$PLAT" = macos ] && probe "formulae.brew.sh" "https://formulae.brew.sh/api/formula/git.json"

# TLS interception: a corporate proxy re-signs certificates and breaks pip, curl installers and gcloud.
ISSUER="$(curl -sS -v --max-time 12 https://pypi.org 2>&1 | sed -n 's/.*issuer: .*O=\([^,]*\).*/\1/p' | awk 'NR==1')"
if [ -n "$ISSUER" ]; then
  case "$ISSUER" in
    *"Let's Encrypt"*|*DigiCert*|*Google*|*Amazon*|*Sectigo*|*GlobalSign*|*"GTS"*)
      add "tls not intercepted" OK "$ISSUER" "public CA" "" ;;
    *) add "tls not intercepted" WARN "$ISSUER" "public CA" \
         "A proxy is re-signing TLS. pip, curl installers and gcloud may fail. Get your CA bundle from IT and set REQUESTS_CA_BUNDLE and SSL_CERT_FILE." ;;
  esac
fi

# git clone over https must actually work, not just github.com responding
if command -v git >/dev/null 2>&1; then
  if git ls-remote --exit-code https://github.com/git/git >/dev/null 2>&1; then
    add "git clone works" OK "yes" "required" ""
  else
    add "git clone works" FAIL "blocked" "required" "github.com answers but git over HTTPS is blocked. Check proxy settings."
  fi
fi

# ---------- verdict ----------
VERDICT="GO"; CODE=0
[ "$WARN" -gt 0 ] && { VERDICT="GO WITH CAVEATS"; CODE=1; }
[ "$FAIL" -gt 0 ] && { VERDICT="NO-GO";           CODE=2; }

if [ "$JSON" = 1 ]; then
  printf '{"verdict":"%s","exit":%d,"ok":%d,"warn":%d,"fail":%d,"platform":"%s","arch":"%s","checks":[' \
    "$VERDICT" "$CODE" "$OK" "$WARN" "$FAIL" "$PLAT" "$ARCH"
  for i in "${!ROWS[@]}"; do
    IFS='|' read -r n s f r a <<< "${ROWS[$i]}"
    [ "$i" -gt 0 ] && printf ','
    printf '{"check":"%s","status":"%s","found":"%s","needs":"%s","advice":"%s"}' "$n" "$s" "$f" "$r" "$a"
  done
  printf ']}\n'
  exit "$CODE"
fi

echo
echo "  PRE-SETUP REPORT CARD"
echo "  $OSNAME $OSVER · $ARCH · $(date +%Y-%m-%d)"
printf '  '; printf '%.0s=' {1..72}; echo
printf "  %-22s %-9s %-22s %s\n" CHECK STATUS FOUND NEEDS
printf '  '; printf '%.0s-' {1..72}; echo
for r in "${ROWS[@]}"; do
  IFS='|' read -r n s f req a <<< "$r"
  [ "${#f}" -gt 22 ] && f="${f:0:19}..."
  printf "  %-22s %-9s %-22s %s\n" "$n" "$s" "$f" "$req"
done
printf '  '; printf '%.0s-' {1..72}; echo
printf "  %d OK · %d warning · %d blocking\n" "$OK" "$WARN" "$FAIL"
echo
if [ "$FAIL" -gt 0 ] || [ "$WARN" -gt 0 ]; then
  echo "  WHAT TO DO"
  for r in "${ROWS[@]}"; do
    IFS='|' read -r n s f req a <<< "$r"
    [ "$s" != OK ] && [ -n "$a" ] && printf "  [%s] %s\n        %s\n" "$s" "$n" "$a"
  done
  echo
fi
printf '  VERDICT: %s\n\n' "$VERDICT"
case "$CODE" in
  0) echo "  This laptop can run the lab. Next:  bash setup/install.sh" ;;
  1) echo "  This laptop can probably run the lab, but read the warnings above first."
     echo "  If any look serious for your machine, use the provided lab VM instead."
     echo "  To continue anyway:  bash setup/install.sh" ;;
  2) echo "  This laptop should NOT be used for the lab."
     echo "  Fix the blocking items above, or use the provided lab VM." ;;
esac
echo
exit "$CODE"
