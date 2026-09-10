# bwg-lab-setup

Set up a personal laptop — macOS, Linux, or Windows via WSL2 — with the software stack for the
Build with Google Track 2 lab.

---

## ⚠️ Read this before you run anything

**This is not an official Google product, project, or repository.** It is an independent, personal
project. It is not created, endorsed, sponsored, supported, or maintained by Google LLC or any of
its affiliates. Nothing in this repository represents the views of Google, and no Google warranty,
service level, or support commitment applies to it.

**Use the lab-provided virtual machine instead.** The VM is the supported, tested environment for
this lab, and it is what you should use unless you have a specific reason not to. This repository
exists only for experienced users who are comfortable administering their own machine, who have read
these scripts, and who accept the risks of running them. If you are unsure whether that describes
you, use the VM.

**These scripts change your computer.** They install system packages, add third-party package
repositories and their signing keys, download and execute installer scripts from the internet,
create and delete directories under your home directory, and append lines to your shell profile. On
Linux and WSL2 they invoke `sudo` and therefore run commands with administrative privileges. Run
`bash setup/install.sh --dry-run` to print every command before any of it executes.

**No warranty.** This software is provided on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
ANY KIND, either express or implied, including without limitation any warranties of TITLE,
NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE. See the
[LICENSE](LICENSE) for the governing terms.

**You assume all risk, and all liability is disclaimed.** To the maximum extent permitted by
applicable law, in no event shall the author, the copyright holder, or any contributor be liable to
you for any direct, indirect, incidental, special, exemplary, or consequential damages of any
character arising out of or in any way related to your use of, or inability to use, this software.
This includes, without limitation, damages for loss of data, corruption or deletion of files,
damage to or misconfiguration of an operating system, an unusable or unbootable device, loss of
profits, business interruption, or any charges incurred against any cloud account — even if advised
of the possibility of such damages.

**You are solely responsible** for deciding to run this software, for any changes it makes to any
system you run it on, and for any consequences that follow. **Back up anything you cannot afford to
lose before you begin.**

---

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
- **Sign in to Antigravity and `agy` with the Qwiklabs account issued for this lab.** Not your
  personal Google account, and not your work or corporate account. See
  [Which account to use](#which-account-to-use).
- macOS 13+, or a Linux with glibc 2.28+ (Ubuntu 20.04+ / Debian 10+), or Windows 10 build 19044+
  with WSL2 and WSLg
- 8 GB RAM minimum, 16 GB recommended · 15 GB free disk · 4 CPU cores recommended
- Homebrew on macOS
- A Google Cloud project you can use

Native Windows is **not supported**: a required package (`uvloop`) publishes no Windows builds.
Use WSL2.

## Which account to use

**Use only the Qwiklabs account you were given for this lab**, in Antigravity, in `agy`, and in
`gcloud`. Do not use a personal Google account, and do not use a work or corporate account.

Why this matters:

- The lab's cloud project, its agents, and its permissions all belong to the issued account. A
  different identity will not see them, and the exercises will fail in ways that look like broken
  tooling rather than a wrong login.
- Signing in with a corporate account can apply your organisation's policies to the session, and may
  route lab activity through accounts and audit logs that have nothing to do with the lab.
- Anything the lab creates while you are signed in as yourself lands in **your** project, and any
  charges land on **your** billing account.

Before you start, confirm all three agree:

```bash
gcloud auth list                  # the active account must be the lab account
gcloud config get-value project   # must be the lab project
agy --version                     # then check Antigravity's own signed-in account in the IDE
```

If you are already signed in as someone else, sign out of Antigravity first, and use a separate
gcloud configuration for the lab so you do not disturb your normal setup:

```bash
gcloud config configurations create lab
gcloud auth login                 # the lab account
gcloud auth application-default login
```

`setup/preflight.sh` reports the active account and warns if it does not look like a lab account,
but it cannot tell for certain — the check is yours to make.

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
