# bwg-lab-setup

Set up a personal laptop — macOS, Linux, or Windows via WSL2 — with the software stack for the
Build with Google **Track 2 and Track 3** labs, so you can run them without the provided cloud VM.

Pick your track with `--track 2` or `--track 3`. Without the flag the installer asks, and falls back
to Track 2 when there is no terminal to ask on. See [Which track](#which-track).

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

**Software versions are pinned and NOT actively maintained.** This repository installs specific,
pinned versions of third-party software, and it is not monitored for security advisories. Those
versions will age. A package pinned here today may be found to contain a security vulnerability
tomorrow, and **no notice of any kind will be given to you** — there is no advisory feed, no
security patching process, no update mechanism, and no commitment to publish a fix or to respond to
one. Neither the author nor any contributor undertakes to track, disclose, remediate, or notify you
of any vulnerability in this repository or in anything it installs. **Assessing, monitoring, and
patching the software on your machine is entirely and solely your responsibility**, including
checking these pins against current advisories before you run them and keeping the resulting
installation up to date afterwards.

**You are solely responsible** for deciding to run this software, for any changes it makes to any
system you run it on, and for any consequences that follow. **Back up anything you cannot afford to
lose before you begin.**

---

Everything is pinned to a reference environment. Verified 19 August 2026.

## Which track

Both tracks share the same toolchain: Python 3.14, the pinned package set, the Google Cloud CLI,
Node.js 24, and the `agents-cli` lifecycle skills. What differs is the lab content.

| | Track 2 | Track 3 |
|---|---|---|
| Lab | NovaSmart governance lab | Agent-first app on Google Cloud |
| Command | `bash setup/install.sh --track 2` | `bash setup/install.sh --track 3` |
| Lab content | The skills bundled in this repo's `skills/` | The Track 3 starter kit, cloned from GitHub |
| Where you work | `~/Desktop/Session1`, `Session2`, `Session3` | `~/Desktop/build-with-gemini` |
| Also installs | none | The GitHub CLI (`gh`), which the kit needs to publish your project |
| Verify with | `bash setup/verify.sh --readiness` | `bash setup/verify.sh --readiness --track 3` |

If you do not pass `--track`, the installer asks you. When nothing can ask you, such as a pipe, a CI
job, or `--dry-run`, it sets up **Track 2** and says so on stderr. Track 2 is unchanged in every
respect for anyone who does not pass the flag.

### About the Track 3 starter kit

Track 3 works out of a starter kit that lives in a **separate community repository**,
<https://github.com/cszhu/build-with-gemini>. It is **not** part of this repository, it is **not**
maintained by this repository's author, and like this repository it is **not an official Google
product**. `install.sh --track 3` clones it as-is. It does not vendor it, patch it, or review it for
you. Read that repository before you run anything it ships, exactly as you should read this one.

You can point somewhere else with `--kit-url URL`, for example at your own fork or an offline
mirror, and change where it lands with `--kit-dir DIR`.

The clone is treated as **yours** from the moment it exists, because that is where you build your
project. Re-running the installer leaves an existing clone alone. Even `--force` does not delete it:
it moves the old directory aside with a timestamped name and clones a fresh one next to it.

You do **not** need to run anything to register the kit's skills. Antigravity reads the `.agents/`
folder of whatever workspace you open, so opening the cloned folder is what loads them.

## Three ways to do this

Pick one. They produce the same environment, and `setup/verify.sh` checks all three the same way.

| | Path | Best for |
|---|---|---|
| **A** | [Ask the assistant](#a--ask-the-assistant) | You have Antigravity and want it driven for you |
| **B** | [Run the scripts](#b--run-the-scripts) | You want automation without an agent |
| **C** | [Do it by hand](manual_setup.md) | You want to see and approve every command |

Something not working? **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)**.

---

## A — Ask the assistant

Clone the repository, open **that folder** in Antigravity, and say:

> **Set up my laptop for the lab.**

Or do it in one step, pasting the repository URL into the prompt:

> **Set up my laptop for the lab. Everything you need is at
> https://github.com/lavinigam-gcp/bwg-lab-setup — clone it and follow its setup process.**

Both work; the one-step version has been run on macOS with Gemini 3.8 Flash. The two-step version is
marginally safer, because Antigravity loads skills when a session **starts** — a repository cloned
mid-session has its `SKILL.md` read as an ordinary file rather than loaded as steering. Clone first,
open the folder, then prompt if you want the skill fully in force.

Either way the assistant runs preflight, shows you the report card, lists exactly what it will
change, and **waits for your go-ahead** before installing anything.

---

## B — Run the scripts

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
bash setup/install.sh               # asks which track, then installs it
```

Or name the track up front, which is what you want in a script or over a slow link:

```bash
bash setup/install.sh --track 2     # NovaSmart governance lab
bash setup/install.sh --track 3     # agent-first app, with the Track 3 starter kit
```

**Step 3 — confirm you are ready.** Use the same track you installed:

```bash
bash setup/verify.sh --readiness              # Track 2
bash setup/verify.sh --readiness --track 3    # Track 3
```

`verify.sh` checks the shared toolchain for both tracks, then the part that belongs to your track:
session folders and the governance-lab skill for Track 2, the cloned starter kit and `gh` for
Track 3. It never reports a Track 2 requirement as a failure on a Track 3 machine, or the reverse.

---

## C — Do it by hand

Every command, step by step, with no scripts: **[manual_setup.md](manual_setup.md)**.

It is derived from `setup/install.sh` and runs the same commands in the same order, so it produces
the same environment. Use it if you want to approve each step yourself, if the installer will not
run on your machine, or if you simply want to understand what it does.

## Prerequisites

- **Antigravity IDE** — install it yourself from <https://antigravity.google/download>. It is the
  editor the labs run in, so it cannot install itself. The separate `agy` command line tool is
  **not** installed and is not needed: the labs are played in the IDE and nothing in them calls it.
- **Sign in to Antigravity with the Qwiklabs account issued for this lab.** Not your personal Google
  account, and not your work or corporate account. See
  [Which account to use](#which-account-to-use).
- macOS 13+, or a Linux with glibc 2.28+ (Ubuntu 20.04+ / Debian 10+), or Windows 10 build 19044+
  with WSL2 and WSLg
- 8 GB RAM minimum, 16 GB recommended · 15 GB free disk · 4 CPU cores recommended
- Homebrew on macOS
- A Google Cloud project you can use
- **Track 3 only:** a GitHub account, to publish your finished project. The GitHub CLI (`gh`)
  itself is installed for you by `--track 3`; you do not need it beforehand.

Native Windows is **not supported**: a required package (`uvloop`) publishes no Windows builds.
Use WSL2.

## Which account to use

**Use only the Qwiklabs account you were given for this lab**, in Antigravity and in `gcloud`. Do not use a personal Google account, and do not use a work or corporate account.

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
                                  # then check Antigravity's own signed-in account in the IDE
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
| Python packages | 120, pinned in `setup/requirements-lock.txt` | yes |
| Google Cloud CLI | current | yes |
| The Track 2 lab skills | bundled in `skills/` | Track 2 |
| The Track 3 starter kit | cloned from a community repo | Track 3 |
| GitHub CLI (`gh`) | current | Track 3 |
| Node.js | 24 | no — parity with the reference image |
| ffmpeg, VS Code, Playwright's browser | current | no — `--with-extras` |

Roughly 850 MB of downloads, 45–90 minutes, mostly waiting.

## Command reference

```
setup/preflight.sh [--json]
  exit 0 GO · 1 GO WITH CAVEATS · 2 NO-GO · 3 could not assess

setup/install.sh [options]
  --dry-run          print every command, change nothing
  --only STEP        run one step: tools python skills sessions register
  --with-extras      also install ffmpeg, VS Code, Playwright's browser
  --force            rebuild an existing virtual environment
  --yes              do not prompt (does NOT override a preflight NO-GO)
  --skip-preflight   do not run preflight first
  --root DIR         parent of Desktop/SessionN (default: $HOME)
  --skills-src DIR   use lab skills from elsewhere instead of the bundled copy

setup/verify.sh [--json] [--fix-hints] [--readiness]
  exit 0 all pass · 1 drift · 2 missing · 3 no virtual environment
```

The Python set is installed with `--no-deps`, because `requirements-lock.txt` is the complete
resolved environment. Without that flag the resolver re-adds packages that were deliberately
removed — `google-agents-cli` hard-requires `google-cloud-aiplatform[evaluation]`, whose extra pulls
in LiteLLM and an OpenAI client that nothing in these labs uses — and it adds them unpinned.

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
| macOS (Apple Silicon) | Preflight and the assistant flow confirmed on macOS 26.6.2 / arm64 with Gemini 3.8 Flash — report card correct, account warning correct, approval gate held. The install itself not yet completed end to end |
| macOS (Intel) | Not yet run |

Intel Macs need Rust and the Xcode command line tools, because the pinned `cryptography` version no
longer publishes an Intel wheel. `install.sh` detects this and offers to install them.

Problems: **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** covers every failure we have seen, by
operating system. See [CONTRIBUTING.md](CONTRIBUTING.md) for what to include in an issue.
Licensed under [Apache 2.0](LICENSE).
