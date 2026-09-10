# Manual setup

Do everything by hand, with no scripts. Use this if you want full control over what touches your
machine, if you cannot run the installer, or if you want to understand exactly what it does.

**Read the disclaimer in the [README](README.md) first.** It applies here too: this is not an
official Google repository, versions are not maintained for security, and you assume all risk.
The lab-provided VM remains the supported option.

Every command below is what `setup/install.sh` runs, in the same order. Doing this by hand and
running the installer should produce the same environment, and `setup/verify.sh` checks either way.

**Time:** 45–90 minutes, mostly downloads (~850 MB).

---

## Before you start

**Antigravity IDE** — install it yourself from <https://antigravity.google/download>. It is the
editor the labs run in, so it cannot install itself.

**Sign in with the Qwiklabs account issued for the lab.** Not a personal Google account and not a
work or corporate one. A different identity cannot see the lab's project or agents, and anything you
create lands in your own project and bills your own account. Keep it separate:

```bash
gcloud config configurations create lab
```

**Check your machine can cope.** If you would rather not run the script at all, the thresholds are:
macOS 13+ / glibc 2.28+ / Windows 10 build 19044+ with WSL2 · x86_64 or arm64 · 4 cores · 8 GB RAM
(16 recommended) · 15 GB free disk. Otherwise:

```bash
bash setup/preflight.sh        # read-only, changes nothing
```

Throughout, `~/novasmart-lab` is the toolchain and `~/Desktop/Session1|2|3` are the lab workspaces.

---

## Step 1 — System tools

Installs `git`, the Google Cloud CLI, Node.js 24, and `uv`.

### macOS

```bash
brew install git
brew install --cask gcloud-cli
brew install node@24
echo 'export PATH="'"$(brew --prefix)"'/opt/node@24/bin:$PATH"' >> ~/.zshrc
exec zsh
curl -LsSf https://astral.sh/uv/install.sh | sh
```

`node@24` is keg-only, which is why it needs the `PATH` line. Use `~/.bash_profile` if your shell is
bash.

**Intel Macs only.** One pinned package (`cryptography`) no longer publishes an Intel wheel and must
be compiled:

```bash
xcode-select --install
brew install rust
```

### Linux and WSL2

```bash
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
     curl wget gnupg ca-certificates apt-transport-https git build-essential

# Google Cloud CLI
sudo install -m 0755 -d /usr/share/keyrings
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
  | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null

# Node.js 24
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E DEBIAN_FRONTEND=noninteractive bash -

sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y google-cloud-cli nodejs

curl -LsSf https://astral.sh/uv/install.sh | sh
```

`DEBIAN_FRONTEND=noninteractive` must be passed **through** `sudo`. `sudo` runs with `env_reset` and
strips it, and without it `tzdata` opens an interactive prompt that hangs the install with no output.

### Both

```bash
uv python install 3.14
```

---

## Step 2 — The Python environment

```bash
mkdir -p ~/novasmart-lab
uv venv --seed --python 3.14 ~/novasmart-lab/.venv
source ~/novasmart-lab/.venv/bin/activate

uv pip install --no-deps -r setup/requirements-lock.txt
```

Three details that matter:

- **`--seed`** installs `pip` into the environment. Without it the venv has none.
- **`--no-deps` is required, not an optimisation.** `requirements-lock.txt` is the complete resolved
  set of 120 packages. Without the flag the resolver adds more — `google-agents-cli` hard-requires
  `google-cloud-aiplatform[evaluation]`, whose extra pulls in LiteLLM and an OpenAI client that
  nothing in these labs uses — and adds them unpinned.
- You must `source ~/novasmart-lab/.venv/bin/activate` in **every new terminal** before using the
  lab tools.

---

## Step 3 — The `agy` CLI

```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc   # ~/.bashrc on Linux/WSL2
exec "$SHELL"
agy --version
```

---

## Step 4 — Make the lab skills portable

The bundled skills in `skills/` are already published portable, so normally there is nothing to do.
Confirm:

```bash
grep -rlE '(^|[[:space:]`"(])/config([^a-zA-Z]|$)' skills/ || echo "already portable"
```

If that lists files, they came from a copy taken off the lab VM, where the home directory is
`/config`. Rewrite them:

```bash
grep -rlE '(^|[[:space:]`"(])/config([^a-zA-Z]|$)' skills/ | while read -r f; do
  sed -i.bak -E "s#(^|[[:space:]\`\"(])/config([^a-zA-Z]|\$)#\1$HOME\2#g" "$f"; rm -f "$f.bak"
done
```

Match `/config` only where it **starts a path**. A blanket replace corrupts `/configure` inside
documentation URLs, and a looser guard still corrupts `deployment/config` in prose. Also set:

```bash
echo 'export NOVASMART_SCORECARD_HOME="$HOME"' >> ~/.zshrc   # ~/.bashrc on Linux/WSL2
```

---

## Step 5 — Create the session folders

Antigravity works on a folder. Each session folder is a self-contained workspace with its own copy
of the skills, matching the lab VM's layout.

```bash
for s in Session1 Session2 Session3; do
  mkdir -p ~/Desktop/$s/.agents/skills
  cp -r skills/novasmart-governance-lab ~/Desktop/$s/.agents/skills/
  for d in build-demo bwgtrack2-demo-build; do
    [ -d skills/build-demo/$d ] && cp -r skills/build-demo/$d ~/Desktop/$s/.agents/skills/
  done
done
```

**Every skill must be a direct child of `.agents/skills/`, with its `SKILL.md` at the top of its own
directory.** The tooling scans one level deep and no further, which is why `build-demo`'s children
are copied individually rather than copying the parent folder. A nested skill fails silently rather
than with an error. Confirm:

```bash
for d in ~/Desktop/Session1/.agents/skills/*/; do
  printf "%-28s %s\n" "$(basename "$d")" "$([ -f "$d/SKILL.md" ] && echo ok || echo MISSING-SKILL.md)"
done
```

---

## Step 6 — Register the skills

```bash
cd ~/Desktop/Session1
source ~/novasmart-lab/.venv/bin/activate
agents-cli setup
agents-cli update
agents-cli info
```

**Run these once, during setup, and not again.** `agents-cli setup` also pulls in unrelated
general-purpose skills from a public repository — harmless now, but an unwanted change if run in the
middle of an exercise.

`agents-cli info`'s **skills count refers to the CLI's own toolkit**, not the lab's. Confirm the lab
skills with `ls ~/Desktop/Session1/.agents/skills`. And `setup` exiting 0 is not proof it worked —
read the `info` output.

---

## Step 7 — Google Cloud

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_LAB_PROJECT_ID
gcloud auth application-default set-quota-project YOUR_LAB_PROJECT_ID
```

**Do not skip the quota-project line.** Without it several APIs return `403` with a message about
`x-goog-user-project` that reads like a permissions problem and is not one.

Confirm the account is the lab one, not yours:

```bash
gcloud auth list
```

Your account also needs IAM roles equivalent to what the lab VM's service account has. **Ask your
lab administrator for the list** rather than guessing — several are non-obvious. Do not download a
service-account key to impersonate it; a long-lived key on a laptop is a worse risk than the gap it
closes.

---

## Step 8 — Check it worked

```bash
bash setup/verify.sh --readiness
```

Expect **12 of 12 checks OK** and a readiness summary. Two lines are worth reading closely:

- **`packages 120`** — anything else means the Python install diverged, most likely a missing
  `--no-deps`.
- **`no-vendor-sdk 0`** — anything above zero means the resolver re-added LiteLLM or an OpenAI
  client.

Then open `~/Desktop/Session1` in Antigravity and begin.

---

## Optional extras

Only needed for the optional demo-recording exercises. Skip them for a standard lab run.

```bash
# macOS
brew install ffmpeg
brew install --cask visual-studio-code

# Linux / WSL2
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ffmpeg
wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
  | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y code

# Both, inside the virtual environment
playwright install chromium
```

---

## If something goes wrong

`setup/verify.sh --fix-hints` prints the repair for each failing check. The full list, by operating
system, is in **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)**. The ones that catch people most often:

| Symptom | Cause |
|---|---|
| `cryptography` fails to build on an Intel Mac | No Intel wheel for the pinned version. Install Rust and Xcode command line tools |
| The install hangs with no output on Linux | `DEBIAN_FRONTEND` not passed through `sudo`; `tzdata` is waiting on a prompt |
| `uvloop` will not install on Windows | It has no Windows build. Use WSL2 |
| `agents-cli: command not found` | The virtual environment is not activated |
| An exercise writes a file and it is nowhere | Skills still contain `/config` paths — Step 4 |
| Everything installs but exercises find nothing | Expected until the Google Cloud project is provisioned |
