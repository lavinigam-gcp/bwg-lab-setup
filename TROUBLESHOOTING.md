# Troubleshooting

Every failure we have seen, across macOS, Linux and WSL2, with the cause and the fix.

---

## Start here

Two commands answer most questions. Both are read-only.

```bash
bash setup/preflight.sh          # can this machine do it at all?
bash setup/verify.sh --fix-hints # what is wrong with the current install?
```

`--fix-hints` prints the exact `install.sh --only …` command for each failing check. Fix the cause,
re-run that one step, re-verify. **Do not start over** — `install.sh` is idempotent and re-running a
finished step does nothing.

### Exit codes

| Script | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| `preflight.sh` | GO | GO WITH CAVEATS | NO-GO | could not assess |
| `verify.sh` | all pass | drift | something missing | no virtual environment |

---

## The five most common

**`agents-cli: command not found`, or `python` is the wrong version.**
The virtual environment is not active. Run `source ~/novasmart-lab/.venv/bin/activate`. You need
this in **every new terminal** — it is not permanent, by design.

**`packages` is not 120.**
The Python install diverged, almost always a missing `--no-deps`. `requirements-lock.txt` is the
complete resolved set; without the flag the resolver adds more, unpinned.
Fix: `bash setup/install.sh --only python --force`.

**`no-vendor-sdk` is above 0.**
LiteLLM or an OpenAI client came back. Same cause as above: `google-agents-cli` hard-requires
`google-cloud-aiplatform[evaluation]`, and that extra pulls them in whenever the resolver is allowed
to run. Same fix.

**An exercise writes a file and it is nowhere to be found.**
The skills still contain `/config` paths — the home directory *inside the lab VM's container*, which
does not exist on your machine. Check with:

```bash
grep -rlE '(^|[[:space:]`"(])/config([^a-zA-Z]|$)' ~/Desktop/Session1/.agents/skills
```

Fix: `bash setup/install.sh --only skills`. This can come back after a `git pull`.

**Everything installs cleanly but the lab exercises find nothing in Google Cloud.**
Expected, and not a setup problem. The lab's agents, datasets and gateways live in a Google Cloud
project that has to be provisioned separately. Ask your lab administrator. See
[Expected failures](#expected-failures).

**`node` or `gcloud` reported MISSING by verify.**
The tools step did not complete, or the binary is not on `PATH` in this shell.
Fix: `bash setup/install.sh --only tools`, then open a new terminal. On macOS also see the keg-only
note below.

**Looking for `agy`?** It is not installed and not needed — the labs run in the Antigravity IDE and
nothing in them calls the CLI. Install it separately if you want a terminal client.

---

## macOS

**`cryptography` fails to build (Intel Macs).**
The pinned version no longer publishes an Intel wheel, so it compiles from source and needs Rust:

```bash
xcode-select --install
brew install rust
bash setup/install.sh --only python
```

If you are blocked and need to move on, `uv pip install cryptography==48.0.1` installs from a wheel.
You are then one package away from the reference environment — acceptable for learning, and worth
knowing rather than discovering later.

Apple Silicon is unaffected.

**`node: command not found` right after installing it.**
`node@24` is keg-only in Homebrew, so it is not linked into `PATH`:

```bash
echo 'export PATH="'"$(brew --prefix)"'/opt/node@24/bin:$PATH"' >> ~/.zshrc
exec zsh
```

Use `~/.bash_profile` if your shell is bash, not `~/.bashrc`.

**`Homebrew is required on macOS`.**
Install it from <https://brew.sh> and re-run.

**Antigravity will not open, or macOS blocks it.**
Open it once from Applications by hand so macOS records your approval, then retry.

**Rosetta.** If you are on Apple Silicon but running an x86_64 shell under Rosetta, `uname -m`
reports `x86_64` and you will get Intel wheels on an ARM machine. Preflight detects the real
architecture via `sysctl`, so trust its report over `uname`.

---

## Linux

**The install hangs with no output during the tools step.**
`DEBIAN_FRONTEND` is not reaching `apt`. `sudo` runs with `env_reset` and strips it, so `tzdata`
opens an interactive prompt and waits forever. Every `apt-get` call must carry it explicitly:

```bash
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y …
```

The scripts already do this. If you are following the manual steps, do not drop it. To confirm this
is what is happening: `ps -eo etime,cmd | grep -i debconf`.

**`Antigravity will not start`, mentions sandbox.**
Set the sandbox permissions rather than disabling it:

```bash
AG_DIR=$(ls -d /opt/antigravity/Antigravity-*/ | head -1)
sudo chown root:root "${AG_DIR}chrome-sandbox"
sudo chmod 4755 "${AG_DIR}chrome-sandbox"
```

**Never add `--no-sandbox`.** It is the advice you will find online and it disables a real browser
security boundary.

**`glibc 2.28+` FAIL in preflight.**
Antigravity will not launch on older glibc. This is not workaroundable — upgrade the distribution or
use the lab VM.

**Google Chrome will not install on arm64.**
Google publishes no arm64 `.deb`. Chrome is optional; any browser works for sign-in.

---

## WSL2

**Antigravity does not open at all.**
WSLg is missing. In PowerShell run `wsl --version`. If the command is unrecognised, you have the
older in-box WSL — install WSL from the Microsoft Store and restart.

**Preflight reports plenty of free disk, but the install fails with no space.**
WSL2's virtual disk is allocated up to 1 TB by default, so `df /` is fiction. The real space is on
Windows. Check `df -h /mnt/c` — preflight does this too and fails if `C:` is short.

**Preflight reports about half the RAM the machine has.**
Expected. WSL2 defaults to 50% of host memory. Raise it in `%UserProfile%\.wslconfig`:

```ini
[wsl2]
memory=12GB
```

Then `wsl --shutdown` and reopen.

**Everything is very slow, and file changes are not noticed.**
Your working directory is under `/mnt/c/`. Move it into the Linux filesystem (`~/novasmart-lab`,
`~/Desktop/SessionN`). Crossing the filesystem boundary is slow and breaks file watching.

---

## Native Windows (unsupported)

**`uvloop` will not install.**
It has no Windows build and never has, so the pinned set cannot be installed as written. Use WSL2.

If you truly cannot: remove the `uvloop` line from `requirements-lock.txt` before installing —
`uvicorn` falls back to the standard asyncio loop, slower but working — fetch the `agy` Windows
binary by hand from the release manifest, and expect the shell scripts not to run. This combination
has never been tested end to end.

---

## Network and proxies

**TLS errors, or `pip`/`curl` installers failing on a corporate network.**
An intercepting proxy is re-signing certificates. Preflight flags this as `tls not intercepted WARN`.
Get your organisation's CA bundle from IT and point the tools at it:

```bash
export REQUESTS_CA_BUNDLE=/path/to/ca-bundle.crt
export SSL_CERT_FILE=/path/to/ca-bundle.crt
```

**Never disable certificate verification** to get past this.

**A preflight endpoint shows `unreachable`.**
Something between you and it is blocking. The install will fail later at the step that needs it, so
fix it first. `github.com` and `pypi.org` are not optional.

**`git clone works` FAIL while `github.com` shows OK.**
The host answers but git over HTTPS is blocked — usually a proxy that permits browsing and not git.

---

## Google Cloud

**`403` with a message about `x-goog-user-project`.**
You missed the quota project. It reads like a permissions problem and is not one:

```bash
gcloud auth application-default set-quota-project YOUR_LAB_PROJECT_ID
```

**Preflight warns about your Google account.**
It does not look like a lab account. Use the **Qwiklabs account issued for the lab** — not personal,
not corporate. A different identity cannot see the lab's project or agents, and anything you create
lands in your own project and bills your own account. Keep them separate:

```bash
gcloud config configurations create lab
gcloud auth login
gcloud auth application-default login
```

Preflight cannot tell for certain what a valid lab account looks like, so the check is advisory. The
judgement is yours.

**`PERMISSION_DENIED` during an exercise.**
Your account is missing an IAM role the lab VM's service account has. Ask your lab administrator for
the list — several are non-obvious, and guessing wastes time. Do not download a service-account key
to impersonate it.

---

## Skills

**`agents-cli info` says no skills are installed.**
Its **skills count refers to the CLI's own general toolkit**, not the lab's. Check the lab's
separately:

```bash
ls ~/Desktop/Session1/.agents/skills
```

**A skill is on disk but the assistant cannot see it.**
Its `SKILL.md` is nested too deep. Every skill must be a **direct child** of `.agents/skills/`, with
`SKILL.md` at the top of its own directory. The tooling scans one level and no further, and a nested
skill fails silently. Confirm:

```bash
for d in ~/Desktop/Session1/.agents/skills/*/; do
  printf "%-28s %s\n" "$(basename "$d")" "$([ -f "$d/SKILL.md" ] && echo ok || echo MISSING)"
done
```

**The assistant cloned the repository but is not using the skill.**
Antigravity enumerates skills when a **session starts**. A repository cloned mid-session has its
`SKILL.md` read as an ordinary file, not loaded as steering. Open the cloned folder and start a new
session.

**`agents-cli setup` exits 0 but nothing changed.**
Exit 0 is not proof. Read the `agents-cli info` output.

---

## Preflight verdicts

| Verdict | Meaning | What to do |
|---|---|---|
| **GO** | Suitable | Continue |
| **GO WITH CAVEATS** | Will probably work | Read every warning. If any looks serious for your machine, use the lab VM |
| **NO-GO** | Something cannot be worked around | Fix the blocking item, or use the lab VM |

`--skip-preflight` exists for repairs and re-runs. **It is not a way to get past a NO-GO.** If
preflight says your machine cannot do this, it is telling you something true.

---

## Expected failures

These are not bugs, and no amount of reinstalling fixes them.

| | Why |
|---|---|
| Exercises find no agents, datasets or gateways | The Google Cloud project has not been provisioned. Separate from this repository entirely |
| `gcp account` warns on a corporate machine | The check is doing its job |
| `adc MISSING` inside a container | ADC lives in `~/.config/gcloud`; a mounted credential elsewhere is not detected |
| Antigravity version newer than the reference | Expected. Versions are checked for presence, not pinned |
| `lab-skills SKIP` | Session folders exist but are empty. Run `install.sh --only sessions` |

---

## Still stuck

Open an issue with the output of both:

```bash
bash setup/preflight.sh
bash setup/verify.sh --fix-hints
```

Include your OS and version, and whether you are on Apple Silicon, Intel, or WSL2. Those two outputs
plus the platform are almost always enough to diagnose it.

`~/novasmart-lab/install.log` has a timestamped record of every command the installer ran, which is
useful when a step failed and you have already closed the terminal.
