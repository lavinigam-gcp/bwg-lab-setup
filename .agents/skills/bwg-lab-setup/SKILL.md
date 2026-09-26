---
name: bwg-lab-setup
description: Set up this laptop for the Build with Google Track 2 or Track 3 lab, or repair a setup that is failing. Use when the user says "set up my laptop", "install the lab environment", "my lab environment is broken", or when a lab exercise fails because tooling or skills are missing.
---

# Laptop setup for the Build with Google Track 2 / Track 3 labs

Drive `setup/install.sh` and `setup/verify.sh` to bring this machine to parity with the lab VM,
then hand back a short list of the things only a human can do.

`verify.sh` is the only source of truth for pass or fail. Never edit it, and never report success
it did not report.

## 1. Pre-flight

1. Confirm the open folder is this repository — it must contain `setup/install.sh` and
   `setup/verify.sh`. If not, stop and tell the user which folder to open.
2. Detect the platform: `uname -s` and `uname -m`.
   - Native Windows is unsupported: `uvloop` publishes no Windows wheels. Direct the user to WSL2.
   - Intel Mac (`Darwin` + `x86_64`) needs Rust for `cryptography`; the script offers to install it.
3. **Establish which track the user is doing, and do it before anything else.** Every command
   below takes `--track`, and the two tracks install different things.
   - Track 2 is the NovaSmart governance lab. It uses the skills bundled in this repo and works
     out of `~/Desktop/Session1|2|3`.
   - Track 3 is the agent-first app. It clones the Track 3 starter kit from a separate community
     repository into `~/Desktop/build-with-gemini`, and also installs the GitHub CLI.
   - If the user has not said, **ask**. Do not guess from the folder they have open. If you pass
     no `--track` to a script, it silently uses Track 2, which is the wrong answer half the time.
   - Once you know, use `--track N` on `preflight.sh`, `install.sh` and `verify.sh` every time,
     including Track 2. Being explicit is what makes the transcript readable afterwards.
4. Run `bash setup/verify.sh --json --track N` first. If it already returns exit 0, say so and
   stop — do not reinstall a working environment.
5. **Run `bash setup/preflight.sh --track N` and show the user the report card.** This is mandatory
   and changes nothing. Its checks are identical for either track; `--track` only records which
   track the card was collected for. Exit 0 GO, 1 GO WITH CAVEATS, 2 NO-GO.
   - On **NO-GO**, stop. Explain which checks blocked it and recommend the lab VM. Do not install
     anything, and do not reach for `--skip-preflight` to get past it.
   - On **GO WITH CAVEATS**, summarise each warning in plain language and ask whether to continue.
6. Show what `install.sh` will change, say roughly how long it takes (45-90 minutes, mostly
   downloads), and **get an explicit go-ahead before changing anything**. `install.sh` asks too,
   so never pass `--yes` unless the user has already said yes in this conversation.

## 2. Install

Run the steps in order, streaming output. Never run the whole thing silently.

```
bash setup/install.sh --yes --track 2      # or --track 3
```

`--yes` suppresses the track question along with every other prompt, so `--track` is not optional
here. Without it the script falls back to Track 2 without asking.

**Track 3 only.** Before running it, tell the user in plain words that this step clones
<https://github.com/cszhu/build-with-gemini> onto their machine, that it is a community repository
which neither this repo nor Google maintains, and that it is not an official Google product. Get
their go-ahead for that specifically. If they would rather use a fork or a mirror, pass
`--kit-url URL`.

The kit is pinned to one commit, held in `KIT_REF` at the top of `setup/install.sh`. Tell the user
which commit they are getting if they ask, read it from that variable rather than from memory, and
use `--kit-ref` if they want a different commit, tag or branch. `--kit-ref ""` follows the default
branch, which means taking whatever that community repository holds that day; only do it if the
user asks for it, and say what it means.

Never delete an existing starter-kit clone, and never suggest `--force` as a way to refresh one.
After the lab starts, that directory holds the user's own project. `--force` moves it aside under a
timestamped name rather than removing it, but it still leaves them with two copies to reconcile,
and when the reason for the failure is an upstream layout change, re-fetching the same upstream
fixes nothing at all. Fetch into a new folder with `--kit-dir DIR` instead, and leave theirs alone.

If the installer reports that the folder has a `.git` but no checkout, an earlier clone was
interrupted. That is repaired by re-running `install.sh --track 3 --only starterkit`, which moves
the unusable directory aside and fetches again. Do not reach for `--force` for this.

Ask before adding `--with-extras`; the optional extras are only for demo-recording exercises and
cost another 300-500 MB.

If a step fails, the script prints the exact `--only` command to retry it. Fix the cause first,
then retry that one step. Do not restart from the beginning.

## 3. Verify

Finish with `bash setup/verify.sh --readiness --track N`, which adds a readiness summary on top of
the parity table: software, lab content, cloud sign-in, and what the human still has to do.

```
bash setup/verify.sh --json --track N
```

Exit codes: `0` all pass, `1` drift, `2` something missing, `3` no virtual environment.

The first seven checks are the shared toolchain and run for both tracks. After that the profiles
diverge, and the `track` field in the JSON tells you which one you are reading:

| Track 2 adds | Track 3 adds |
|---|---|
| `packages`, `sessions`, `lab-skill`, `config-paths` | `kit`, `kit-skills`, `kit-mcp`, `kit-publish`, `gh` |

Do not run the Track 2 profile against a Track 3 machine to "get more coverage". It will report
missing session folders and a missing governance-lab skill, neither of which Track 3 has any use
for, and you will send the user chasing a failure that is not real.

If the virtual environment is somewhere other than `~/novasmart-lab/.venv`, pass `--venv DIR`
rather than reporting exit 3 as a broken install.

For each failing check, read its `fix` field and apply the repair below. Re-run `verify.sh` after
each repair, and keep going until it returns 0 or you are blocked on a human.

## 4. Repair table

| Check fails | Cause | Fix |
|---|---|---|
| `python` | Wrong interpreter, or venv built on an older Python | `uv python install 3.14`, then `install.sh --only python --force` |
| `packages` not 120 | Resolution diverged or a build failed | Re-run `install.sh --only python`. On an Intel Mac see below |
| `packages` is 121 or more | Someone installed an extra package into the lab venv | `install.sh --only python --force`. Plain `--only python` cannot fix this: it never uninstalls anything, so only rebuilding the venv clears it. The venv holds no work, so this is safe |
| `google-adk`, `litellm`, `agents-cli` drift | Someone upgraded a package | `install.sh --only python --force` |
| `config-paths` above 0 | The skills still carry the VM's `/config` paths | `install.sh --only skills --skills-src DIR` |
| `sessions` below 3 | A session folder was deleted or never created | `install.sh --only sessions` |
| `lab-skills` SKIP | The session folders are empty. The skills ARE bundled in this repo, so this means the sessions step did not run | `install.sh --only sessions` |
| `lab-skill` MISSING | A skills source was given but the copy did not land, or is nested too deep | `install.sh --only sessions --skills-src DIR`, then confirm each skill has `SKILL.md` at its own top level |
| `node`, `gcloud` MISSING | Tool step did not complete | `install.sh --only tools` |
| `kit` MISSING (Track 3) | The starter kit was never fetched, or an earlier clone was interrupted and left a `.git` with no checkout | `install.sh --track 3 --only starterkit`. It moves an unusable directory aside and fetches again |
| `kit-skills`, `kit-mcp`, `kit-publish` MISSING (Track 3) | The directory exists but is not the starter kit, or upstream changed its layout | Check `~/Desktop/build-with-gemini` is the right clone. Report a layout change rather than patching around it. Never suggest `--force` here: it moves the user's project folder aside to re-fetch the same unchanged upstream, so it destroys context and fixes nothing. Fetch into a new folder with `--kit-dir DIR` instead |
| `gh` MISSING (Track 3) | Tool step ran as Track 2, or gh was removed | `install.sh --track 3 --only tools`, which installs it with brew on macOS and apt on Linux and WSL2 |
| Installer cannot fetch the kit (Track 3) | That community upstream was renamed, deleted or made private, or the network blocks it | It fails fast and says so rather than hanging on a credential prompt. Nothing is half-applied. Re-run, or pass `--kit-url` pointing at a fork or an offline mirror |
| `verify.sh` exits 64, `unknown option` | A mistyped or invented flag | Read `verify.sh --help`. It refuses unknown flags on purpose: it used to ignore them and silently run the Track 2 profile on a Track 3 machine |
| `sessions` or `lab-skill` fails on a Track 3 machine | You ran the wrong profile | Re-run with `--track 3`. This is not a real failure |
| user asks about `agy` | Not installed by design; the labs run in the IDE | Say so; do not install it |
| exit 3 | No virtual environment | `install.sh --only python` |

TROUBLESHOOTING.md in the repository root lists every known failure by operating system; consult
it before improvising a fix. Known environment failures that are not the script's fault:

- **`cryptography` will not build on an Intel Mac** — no Intel wheel exists for the pinned version.
  Run `xcode-select --install` and `brew install rust`, then retry. If the user is blocked,
  `uv pip install cryptography==48.0.1` installs from a wheel and leaves them one package from the
  image; say so plainly rather than hiding it.
- **TLS errors on a corporate network** — an intercepting proxy. Ask IT for the CA certificate and
  set `REQUESTS_CA_BUNDLE` and `SSL_CERT_FILE`. Do not disable certificate verification.
- **Antigravity will not start on Linux or WSL2** — set the `chrome-sandbox` permissions. Never add
  `--no-sandbox`; it disables a real security boundary.

## 4b. Check which account is signed in

The lab is played with the **Qwiklabs account issued for it** — never a personal Google account and
never a work or corporate one. A different identity cannot see the lab's project or agents, and
anything created lands in the user's own project and bills their own account.

Preflight reports the active account and flags anything that does not look like a lab account. If it
warns, **stop and ask the user to confirm** before installing. Do not assume it is fine because the
tooling works.

## 5. Hand off

These cannot be automated. List whichever still apply, and be specific:

- Sign in to Antigravity with the **Qwiklabs account issued for this lab**, choosing
  **Use Google Cloud project instead**. Not a personal or corporate account.
- `gcloud auth login` and `gcloud auth application-default login`, then
  `gcloud auth application-default set-quota-project PROJECT_ID`. The quota project is not optional.
- Ask the lab administrator for the IAM roles this account needs, and for confirmation that the
  Google Cloud estate has been provisioned. Without it, every exercise fails on its first real call
  even though the laptop is correct.
- Reopen Antigravity on the folder for the track: `~/Desktop/Session1` for Track 2, or
  `~/Desktop/build-with-gemini` for Track 3. Opening the folder is also what loads its skills, so
  name the exact folder rather than saying "open the project".
- **Track 3 only:** the kit's `publish-to-github` skill needs a GitHub account and an interactive
  `gh auth login`. `gh` is installed, but signing in is the user's to do.

## 6. Scope

You may write to: `~/novasmart-lab/`, `~/Desktop/Session1`, `Session2`, `Session3`, and the user's
shell profile. On Track 3, also `~/Desktop/build-with-gemini`, and there only to create the clone,
never to delete or rewrite what is already in it. You may run `setup/install.sh` and
`setup/verify.sh`.

Anything else — installing unrelated software, editing files elsewhere, changing gcloud
configuration beyond the documented commands, or granting IAM roles — **stop and report instead**.
If a step is blocked, say what blocked it and what you would need. Never work around a blocker by
repurposing something that already exists.

Never invent a repository URL. It comes from the clone the user already has.
