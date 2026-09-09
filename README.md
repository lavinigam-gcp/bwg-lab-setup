# bwg-lab-setup

Set up a personal laptop — macOS, Linux, or Windows via WSL2 — with the software stack for the
Build with Google Track 2 lab, so you can do the lab without the provided cloud VM.

Everything is pinned to a reference environment. Verified 19 August 2026.

## Start here

**Step 1 — check your laptop can do this.** Nothing is installed by this step.

```bash
git clone https://github.com/lavinigam-gcp/bwg-lab-setup.git ~/novasmart-lab/setup
cd ~/novasmart-lab/setup
bash setup/preflight.sh
```

You get a report card and one of three verdicts:

| Verdict | Meaning |
|---|---|
| **GO** | Your laptop is suitable. Continue to step 2. |
| **GO WITH CAVEATS** | It will probably work. Read the warnings — if any look serious for your machine, use the lab VM instead. |
| **NO-GO** | Something is missing that cannot be worked around. Fix it, or use the lab VM. |

Preflight checks your OS and version, CPU architecture, cores, memory, free disk, required tools,
and whether you can actually reach GitHub, PyPI, Google Cloud and the Antigravity download — plus
whether a corporate proxy is intercepting TLS, which breaks installers in confusing ways.

**Step 2 — install.** This changes your machine, so it runs preflight again and asks first.

```bash
bash setup/install.sh --dry-run     # optional: see every command it would run
bash setup/install.sh
```

**Step 3 — confirm you are ready.**

```bash
bash setup/verify.sh --readiness
```

### Doing it with the assistant instead

If you already have Antigravity installed, open this folder in it and say:

> Set up my laptop for the lab.

The skill in `.agents/skills/bwg-lab-setup/` runs the same three scripts, reads the results, and
repairs what it can. It will still stop and show you the preflight verdict before installing.

## Prerequisites

- **Antigravity IDE** — install it yourself from <https://antigravity.google/download>. It is the
  editor the lab runs in, so it cannot install itself.
- macOS 13+, or a Linux with glibc 2.28+ (Ubuntu 20.04+ / Debian 10+), or Windows 10 build 19044+
  with WSL2 and WSLg
- 8 GB RAM minimum, 16 GB recommended · 15 GB free disk · 4 CPU cores recommended
- Homebrew on macOS
- A Google Cloud project you can use

Native Windows is **not supported**: a required package (`uvloop`) publishes no Windows builds.
Use WSL2.

## What gets installed

| | Version | Required |
|---|---|---|
| Python | 3.14 | yes |
| Python packages | 128, pinned in `setup/requirements-lock.txt` | yes |
| Google Cloud CLI | current | yes |
| `agy` (Antigravity CLI) | current | yes |
| The lab skills | bundled in `skills/` | yes |
| Node.js | 24 | no — parity with the reference image |
| ffmpeg, VS Code, Playwright's browser | current | no — `--with-extras` |

Roughly 850 MB of downloads, 45–90 minutes, mostly waiting.

## Command reference

```
setup/preflight.sh [--json]
  exit 0 GO · 1 GO WITH CAVEATS · 2 NO-GO · 3 could not assess

setup/install.sh [options]
  --dry-run          print every command, change nothing
  --only STEP        run one step: tools python agy skills sessions register
  --with-extras      also install ffmpeg, VS Code, Playwright's browser
  --force            rebuild an existing virtual environment
  --yes              do not prompt (does NOT override a preflight NO-GO)
  --skip-preflight   do not run preflight first
  --root DIR         parent of Desktop/SessionN (default: $HOME)
  --skills-src DIR   use lab skills from elsewhere instead of the bundled copy

setup/verify.sh [--json] [--fix-hints] [--readiness]
  exit 0 all pass · 1 drift · 2 missing · 3 no virtual environment
```

`install.sh` is idempotent — re-running a finished step does nothing. If a step fails it prints the
single `--only` command that retries just that step.

## What this cannot do for you

Installing Antigravity, its sign-in wizard, `gcloud auth login`, granting your IAM roles, and
provisioning the Google Cloud project all need a human. `verify.sh --readiness` lists whichever are
still outstanding.

Note that a correctly set up laptop will still fail every lab exercise until the **Google Cloud
project** has been provisioned by your lab administrator. That is expected, and separate from
anything here.

## Testing status

| Platform | Status |
|---|---|
| Linux x86_64 | Tested — preflight, dry run, real run, idempotency, failure injection, repair loop |
| WSL2 | Same code path as Linux; not yet run end to end by a human |
| macOS, both architectures | Not yet run end to end by a human |

Intel Macs need Rust and the Xcode command line tools, because the pinned `cryptography` version no
longer publishes an Intel wheel. `install.sh` detects this and offers to install them.

Problems: see [CONTRIBUTING.md](CONTRIBUTING.md) for what to include in an issue.
Licensed under [Apache 2.0](LICENSE).
