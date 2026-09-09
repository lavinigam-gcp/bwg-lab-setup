# Run it, open it, and prove it is real

## 1. The port scheme — 8901 to 8940, first free

⛔ **Ports 3000, 3001, 8080 and 8088 are already taken in this lab** by services the learner may still
need. Never bind them, never suggest them.

**Demo apps use the range 8901-8940, and the app picks the first free port itself.** That is what lets a
learner run two or three demos side by side without a collision or a conversation about ports.

- **How the app finds one:** walk the range, try to `bind()` each port on the loopback address, keep the
  first that succeeds, and serve on it. `assets/starter_app.py` already does this in `first_free_port()`.
- ⛔ **Never hardcode a port**, and never pass one on the command line "just this once" — the second demo
  of the session is the one that breaks.
- **If the whole range is busy, stop and say so.** Do not wander outside it. Name the demos already
  running and let the learner decide which to stop.
- **Bind loopback only.** Nothing in this activity should be reachable from outside the container.

## 2. Recording the port

The port is decided at start-up, so it has to be written down somewhere the learner can find again.

1. **Append one line to the end of `BRIEF.md`**, in the learner's demo folder, the moment the server is
   up — `Running at http://localhost:8903 · started 09:41:12Z`. **Append; never rewrite the brief**, and
   if they start a second demo, append a second line rather than editing the first.
2. **Print the URL as the last line of your reply**, every time, whatever else happened.
3. **Say the port out loud in plain words** — *"it is on port 8903 because 8901 and 8902 already have
   your earlier demos on them."*

## 3. Opening it

**Chrome runs inside this container, so `http://localhost:<PORT>` works from the desktop as-is.** No
tunnel, no port forward, no external URL.

```
python3 app.py &
google-chrome-stable --no-sandbox "http://localhost:<PORT>/" &
```

- ⚠️ **Resolve the interpreter before you assume it.** This lab's own provisioning invokes
  `/opt/venv/bin/python3`, not necessarily a system `python3`. Run `command -v python3` first; if it
  is not on `PATH`, use `/opt/venv/bin/python3`, and say in one line which one you used. A demo that
  dies on `python3: not found` reads as a broken app when it is only the wrong path.
- ⛔ **`xdg-open` is banned.** It may be shimmed to a silent no-op that appends the URL to a text file and
  exits 0 — you will believe you opened a window that never existed.
- **If Chrome does not come up, that is a nuisance, not a failure.** Print the URL and let the learner
  paste it.
- **Run the server in the background** and confirm it is still answering on a later turn before you claim
  it is up.
- **To stop one demo**, stop that process by its port. ⛔ Never `pkill` on a broad pattern — it matches its
  own command line and takes the shell with it.

## 4. Verification — prove it is making real calls and showing real data

**This step is not optional and it is not a formality.** An app that renders a plausible page from
nothing looks exactly like an app that works. Perform every check, then report them in one
`Check | How I verified | Result` table, filled only from what you observed live.

| # | Check | How you do it |
| :-- | :-- | :-- |
| **V1** | The page is being served | `curl -s -o /dev/null -w '%{http_code}' http://localhost:<PORT>/` returns `200` |
| **V2** | ⭐ **A value on the page matches the same command run in the shell** | Pick a panel. Take **the command printed on that panel**, run it yourself in the shell, and compare the value. **Quote both** in your report. This is the check that proves the page is not narrating |
| **V3** | ⭐ **The app calls out on every request, not once at start-up** | Reload the page and confirm the panel timestamps **advance**. Compare one against `date -u +%H:%M:%SZ`; they should be seconds apart, not minutes |
| **V4** | ⭐ **A fresh audit row appeared after the trigger** | You recorded the trigger's UTC send time. Re-run the mandatory `tableDataRead` query with `--freshness=1h` and find at least one row whose `timestamp` is **later** than that send time. Quote the acting principal verbatim |
| **V5** | The `not read` panel is honestly not read | Re-run that panel's own command in the shell and confirm it fails the same way, with the same error text. A `not read` that quietly succeeds in the shell is a bug in the app, not a gap in the estate |
| **V6** | Nothing leaked into the page | `curl -s http://localhost:<PORT>/ | grep -c -E 'ya29\.|BEGIN [A-Z ]*PRIVATE KEY|private_key|@qwiklabs\.net'` returns `0` |
| **V7** | No verdict crept in | Search the served page for a tick, a cross, `PASS`, `FAIL`, `%`, `score` or a badge. Any hit is a build failure — fix it, do not explain it |
| **V8** | The build changed nothing | Re-run the filtered project IAM read on this app's own identity and confirm it is identical to before the build |
| **V9** | You looked at it | Navigate your own browser to the URL, confirm it rendered and the console is clean, and hand back a screenshot |
| **V10** | ⭐ **The learner can re-run a capture without you** | Every file in `evidence/` carries its command, its UTC time and its exit status (`data-palette.md` §0.4). Run the §4.1 check yourself on one capture, then **hand the learner the same paste** so they can run it on any file they like |

**Reporting rules for this table.**

- **A check you did not run says `not verified`** and names the command that would settle it. It never
  gets a pass, and it is never quietly dropped.
- **V4 is the one that is allowed to be slow.** These rows lag minutes. If nothing has landed, **say how
  long you waited and re-run once** — *"waited 4 minutes, re-ran at 09:47:03Z"*. A wait not stated is a
  wait not taken. Still nothing → `not verified`, with the query and the trigger time beside it.
- **A failed check is a finding, not an embarrassment.** Say which row failed, in plain words, and what it
  means for what the page can be used to claim.

### 4.1 The check you hand the learner — "prove these files came from my project"

**Expect the question, and answer it with a command rather than with reassurance.** *"Are these real
reads, or answers you already had?"* is the fair question about any file an assistant writes, and the
honest reply is: **here is how to check, on whichever file you pick.**

Each capture records the command that produced it. This paste reads that command back out, runs it
again, and puts the two answers next to each other. **One block, one filename to change** — give them
the filename of a capture you actually wrote:

```
cd ~/Desktop/<your demo folder>/evidence

python3 - r1_registry_regional.json <<'CHECK'
import json, subprocess, sys
c = json.load(open(sys.argv[1]))
print("This file says it came from:", c["command"])
print("   run at", c["ran_utc"], "- exit status", c["exit_status"])
r = subprocess.run(c["command"], shell=True, capture_output=True, text=True)
print("Running that exact command again now - exit status", r.returncode)
print("   what the file recorded:", json.dumps(c["payload"])[:300])
print("   what came back just now:", r.stdout.strip()[:300])
CHECK
```

**How to read what it prints, in plain words:**

- **The two answers match** — the file came from that command, run against this project. That is the
  whole point of the check.
- **They differ because time has passed** — an audit read (`R12`, `R13`) picks up rows that landed since,
  so the fresh answer is *longer* and contains the old one. Honest, and expected. A listing (`R1`, `R4`,
  `R6`) should look the same unless something in the project actually changed.
- **The command fails now but the file says exit `0`** — a permission or a resource changed since the
  sweep. Say so; it is a finding about the project, not about the app.
- 🔴 **It stops with `KeyError: 'command'`** — **that file has no receipt and is not evidence.** There is
  nothing to re-run, so nothing about it can be checked. Delete it, run the read again, and rebuild the
  panel — do not explain it away.
- 🔴 **The fresh answer has no relationship to the recorded one** — different shape, different fields,
  different project. Treat that as a build failure and say so plainly.

⛔ **Do not run this only on the one capture you know is clean.** Run it on the flattest, least
interesting file in the folder as well — a receipt is worth nothing if it only holds where you chose to
look.

## 5. When it will not start

| Symptom | Do this |
| :-- | :-- |
| Traceback on start | Fix it once. If it fails twice, fall back to a static page built from the `evidence/` files already on disk — the honesty rules are unchanged, and the trigger you already fired still satisfies the baseline, so the page says the read was caused from the command line |
| Whole port range busy | Stop and report which demos hold the ports |
| Chrome will not open | Print the URL; the learner pastes it |
| A panel is empty | It says `not read`, with its command and the error. That is a passing outcome |
