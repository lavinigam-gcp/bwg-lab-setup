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
3. Run `bash setup/verify.sh --json` first. If it already returns exit 0, say so and stop —
   do not reinstall a working environment.
4. **Run `bash setup/preflight.sh` and show the user the report card.** This is mandatory and
   changes nothing. Exit 0 GO, 1 GO WITH CAVEATS, 2 NO-GO.
   - On **NO-GO**, stop. Explain which checks blocked it and recommend the lab VM. Do not install
     anything, and do not reach for `--skip-preflight` to get past it.
   - On **GO WITH CAVEATS**, summarise each warning in plain language and ask whether to continue.
5. Show what `install.sh` will change, say roughly how long it takes (45-90 minutes, mostly
   downloads), and **get an explicit go-ahead before changing anything**. `install.sh` asks too,
   so never pass `--yes` unless the user has already said yes in this conversation.

## 2. Install

Run the steps in order, streaming output. Never run the whole thing silently.

```
bash setup/install.sh --yes
```

Ask before adding `--with-extras`; the optional extras are only for demo-recording exercises and
cost another 300-500 MB.

If a step fails, the script prints the exact `--only` command to retry it. Fix the cause first,
then retry that one step. Do not restart from the beginning.

## 3. Verify

Finish with `bash setup/verify.sh --readiness`, which adds a readiness summary on top of the parity
table: software, lab skills, cloud sign-in, and what the human still has to do.


```
bash setup/verify.sh --json
```

Exit codes: `0` all pass, `1` drift, `2` something missing, `3` no virtual environment.

For each failing check, read its `fix` field and apply the repair below. Re-run `verify.sh` after
each repair, and keep going until it returns 0 or you are blocked on a human.

## 4. Repair table

| Check fails | Cause | Fix |
|---|---|---|
| `python` | Wrong interpreter, or venv built on an older Python | `uv python install 3.14`, then `install.sh --only python --force` |
| `packages` not 120 | Resolution diverged or a build failed | Re-run `install.sh --only python`. On an Intel Mac see below |
| `google-adk`, `litellm`, `agents-cli` drift | Someone upgraded a package | `install.sh --only python --force` |
| `config-paths` above 0 | The skills still carry the VM's `/config` paths | `install.sh --only skills --skills-src DIR` |
| `sessions` below 3 | A session folder was deleted or never created | `install.sh --only sessions` |
| `lab-skills` SKIP | The session folders are empty. The skills ARE bundled in this repo, so this means the sessions step did not run | `install.sh --only sessions` |
| `lab-skill` MISSING | A skills source was given but the copy did not land, or is nested too deep | `install.sh --only sessions --skills-src DIR`, then confirm each skill has `SKILL.md` at its own top level |
| `node`, `gcloud` MISSING | Tool step did not complete | `install.sh --only tools` |
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
- Reopen Antigravity on `~/Desktop/Session1` and continue there.

## 6. Scope

You may write to: `~/novasmart-lab/`, `~/Desktop/Session1`, `Session2`, `Session3`, and the user's
shell profile. You may run `setup/install.sh` and `setup/verify.sh`.

Anything else — installing unrelated software, editing files elsewhere, changing gcloud
configuration beyond the documented commands, or granting IAM roles — **stop and report instead**.
If a step is blocked, say what blocked it and what you would need. Never work around a blocker by
repurposing something that already exists.

Never invent a repository URL. It comes from the clone the user already has.
