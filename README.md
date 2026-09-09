# bwg-lab-setup

Set up a personal laptop — macOS, Linux, or Windows via WSL2 — with the software stack used by the
Build with Google Track 2 lab, so you can run it without the provided cloud VM.

**This repository installs software only.** The lab's own content and skills are distributed
separately; see [Lab skills](#lab-skills).

Everything here is pinned to a reference environment and was verified on 19 August 2026.

## Quick start

```bash
git clone https://github.com/lavinigam-gcp/bwg-lab-setup.git ~/novasmart-lab/setup
cd ~/novasmart-lab/setup
bash setup/install.sh --dry-run     # see exactly what it would do
bash setup/install.sh               # do it
bash setup/verify.sh                # confirm it worked
```

### With the assistant

If you already have Antigravity installed, open this folder in it and say:

> Set up my laptop for the lab.

The skill in `.agents/skills/bwg-lab-setup/` drives the same scripts, interprets the verification
output, and repairs anything that fails.

## What gets installed

| | Version | Needed |
|---|---|---|
| Python | 3.14 | yes — the lab runs on it |
| Python packages | 128, pinned in `setup/requirements-lock.txt` | yes |
| Google Cloud CLI | current | yes |
| `agy` (Antigravity CLI) | current | yes |
| Node.js | 24 | no — parity with the reference image |
| ffmpeg, VS Code, Playwright's browser | current | no — `--with-extras` |

Antigravity itself is a prerequisite: it is the IDE, so you install it yourself from
<https://antigravity.google/download>.

## Prerequisites

- macOS 13+ (Apple Silicon or Intel), Ubuntu 22.04+/Debian 12+, or Windows 10/11 with WSL2
- 15 GB free disk, and 45–90 minutes (mostly downloads, ~850 MB total)
- Homebrew on macOS
- A Google Cloud project you can use

Native Windows is not supported: one required package (`uvloop`) publishes no Windows wheels. Use
WSL2.

## Usage

```
setup/install.sh [options]
  --dry-run          print every command, change nothing
  --only STEP        run one step: tools python agy skills sessions register
  --with-extras      also install ffmpeg, VS Code, Playwright's browser
  --force            rebuild an existing venv
  --yes              do not prompt
  --root DIR         parent of Desktop/SessionN (default: $HOME)
  --skills-src DIR   directory holding the lab skills (see below)

setup/verify.sh [--json] [--fix-hints]
  exit 0 all pass · 1 drift · 2 missing · 3 no virtual environment
```

`install.sh` is idempotent — re-running a finished step does nothing. If a step fails it prints the
one `--only` command that retries just that step.

## Lab skills

The lab's skills are not in this repository. When you receive them, point the installer at them:

```bash
bash setup/install.sh --only skills   --skills-src /path/to/skills
bash setup/install.sh --only sessions --skills-src /path/to/skills
```

That copies them into `~/Desktop/Session1`, `Session2` and `Session3`, and rewrites the paths the
skills hardcode for the lab VM (`/config`) so they resolve on your machine. Without
`--skills-src`, the session folders are created empty and `verify.sh` reports the skills as not
installed rather than failing.

## What this cannot do

Installing Antigravity, its sign-in wizard, `gcloud auth login`, granting your IAM roles, and
provisioning the Google Cloud project all need a human. `verify.sh` will tell you which are
outstanding.

## Testing status

| Platform | Status |
|---|---|
| Linux x86_64 | Tested — dry run, real run, idempotency, failure injection, repair loop |
| WSL2 | Same code path as Linux; not yet run end to end |
| macOS (both architectures) | Not yet run end to end |

Intel Macs need Rust and the Xcode command line tools, because the pinned `cryptography` version no
longer ships an Intel wheel. `install.sh` detects this and offers to install them.
