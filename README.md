# PSA This is fully vibecoded to take advantage of the cowork extended usage limits. pls test before using. I am a degenerate so I never checked for security. this gives a crazy amount of permissions to your agent.

# cowork-wsl-bridge

**Give cloud AI sessions (Claude Cowork and similar) a real shell into your local WSL environment — with zero network setup, no ports, no SSH, no tunnels.**

![Platform](https://img.shields.io/badge/platform-Windows%20%2B%20WSL2-blue)
![Shell](https://img.shields.io/badge/runtime-bash-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)
![Dependencies](https://img.shields.io/badge/dependencies-none%20(bubblewrap%20optional)-brightgreen)
![Version](https://img.shields.io/badge/version-1.1.0-informational)

## The problem

Claude Cowork (and most cloud AI agents) run in an isolated cloud sandbox. They can read and write files in folders you connect from your Windows machine — **but they cannot execute commands on your machine**, and they definitely cannot reach inside WSL, where your actual dev environment, repos, toolchains, and services live.

If you've ever wanted to say *"Claude, run the tests in my WSL repo"* or *"check what's in `~/projects` and fix the build"* from a cloud session — this is the missing piece.

## How it works

The bridge is a ~100-line bash daemon plus a shared Windows folder. No network, no daemon ports, no elevation. The folder **is** the transport:

```
┌───────────────┐   writes inbox/*.cmd    ┌────────────────────────┐   polls inbox/    ┌──────────────┐
│  Claude cloud │ ──────────────────────▶ │   Windows folder        │ ────────────────▶ │  WSL daemon  │
│    session    │                         │  (this repo, seen in   │                   │  runner.sh   │
│               │ ◀────────────────────── │  WSL under /mnt/c/...) │ ◀──────────────── │  runs bash   │
└───────────────┘   reads outbox/*        └────────────────────────┘   writes outbox/  └──────────────┘
```

1. The AI writes a plain bash script to `inbox/<id>.cmd`.
2. `runner.sh`, running inside WSL, picks it up (1s polling), executes it with bash, and writes `outbox/<id>.out` (stdout), `<id>.err` (stderr), `<id>.meta` (exit code, duration), and finally `<id>.done`.
3. The AI polls for `<id>.done` and reads the results back.
4. A `heartbeat.txt` file, refreshed every second, lets the AI verify the daemon is alive before sending anything.

Because WSL mounts your Windows drives at `/mnt/c/...` automatically, the shared folder needs no configuration at all.

## Quick start

```
git clone https://github.com/Aryagarg23/CLAUDE_COWORK_WSL_INTERFACE
```

1. **Connect the cloned folder** to your Claude Cowork session (desktop app → add folder).
2. **Start the bridge** — double-click `start_bridge.bat` (visible window) or `install_autostart.bat` (installs a hidden launcher into your Startup folder, starts it immediately, and re-starts it at every Windows login — no admin rights needed).
3. **Tell Claude**: *"Read CLAUDE.md in the connected folder and use the bridge to run commands in my WSL."* That file teaches any agent the protocol in one read.

That's it. The agent now has a working shell in your WSL environment.

### Recommended: install the companion Claude skill

To make the bridge a **default capability** of every future Cowork session (instead of explaining it each time), attach `skill/wsl-bridge.skill` to a Claude chat and click **Save skill**. From then on, any request that implies local execution ("run this on my machine", "check my repo in wsl") automatically triggers the bridge protocol: heartbeat check, command queueing, result polling, sandbox awareness. The skill reads the folder's `CLAUDE.md` for machine specifics, so it works unmodified on any machine — the source is in `skill/wsl-bridge/SKILL.md` if you want to customize it.

## Automatic startup

| Script | What it does |
|---|---|
| `start_bridge.bat` | Foreground launcher, visible console. Good for first runs / debugging. |
| `start_bridge_hidden.vbs` | Starts the daemon with no window. Safe to run repeatedly (single-instance guard). |
| `install_autostart.bat` | Puts a hidden launcher in your Startup folder + starts the bridge now. |
| `uninstall_autostart.bat` | Removes the autostart entry and stops the daemon. |
| `bridge.conf.example` | Access-control / settings template — copy to `bridge.conf` (gitignored). |
| `skill/wsl-bridge.skill` | Companion Claude skill — save it to your Claude profile so every Cowork session speaks the bridge protocol by default. |

Alternative for cron fans (inside WSL): `@reboot bash /mnt/c/<path>/runner.sh >/dev/null 2>&1 &`

## Protocol reference

| File | Direction | Meaning |
|---|---|---|
| `inbox/<id>.cmd` | agent → WSL | Bash script to execute. `<id>` is any unique name (e.g. `0042_run_tests`). |
| `outbox/<id>.out` | WSL → agent | stdout |
| `outbox/<id>.err` | WSL → agent | stderr |
| `outbox/<id>.meta` | WSL → agent | `exit_code=`, `duration_s=`, `finished=`, `sandbox=` (enforcement mode that applied) |
| `outbox/<id>.done` | WSL → agent | Written **last** — poll for this file; results are complete once it exists. |
| `archive/<id>.cmd` | — | Executed commands, moved out of inbox. |
| `heartbeat.txt` | WSL → agent | Refreshed every second: timestamp, pid, user. Stale heartbeat ⇒ daemon is down. |
| `bridge.log` | — | Daemon log (auto-truncated at 1 MB). |

Details agents should know: commands run with `bash` from `$HOME` by default, CRLF line endings are normalized automatically, files newer than 2 seconds are left alone (write-settle guard), and each command gets a 600 s timeout.

## Restricting what the agent can touch (path allowlist)

By default the agent runs with your full WSL user permissions. If you'd rather scope it to specific repos, copy the example config and list them:

```bash
cp bridge.conf.example bridge.conf
```

```bash
# bridge.conf
ALLOWED_PATHS=(
  "$HOME/projects"
  "$HOME/work/client-repo"
)
SANDBOX="auto"   # auto | require | off
```

When `ALLOWED_PATHS` is non-empty, every command runs inside a [bubblewrap](https://github.com/containers/bubblewrap) sandbox: the **entire filesystem is mounted read-only** except the allowlisted paths, the bridge folder itself, and a private throwaway `/tmp`. The agent can still *read* anything your user can read (it needs to inspect toolchains and configs), but writes outside the allowlist fail with `Read-only file system`. No root, no containers, no daemon config — bubblewrap uses unprivileged user namespaces, which work fine under WSL2.

Install the enforcer once inside WSL:

```bash
sudo apt install bubblewrap
```

Three policies via `SANDBOX` in `bridge.conf`: `auto` (default) enforces when bwrap is installed and degrades to advisory-only otherwise; `require` is fail-closed — commands are refused entirely until bwrap is available; `off` disables restrictions. Every result's `.meta` file reports which mode actually applied (`sandbox=bwrap|advisory|blocked|none`), so neither you nor the agent can be silently confused about the enforcement level. The config is re-read before every command — edit it any time, no restart needed.

`bridge.conf` is machine-specific and `.gitignore`d; only `bridge.conf.example` ships in the repo.

## Configuration

`bridge.conf` (preferred, hot-reloaded) or environment variables before launching `runner.sh`:

| Setting | Default | Meaning |
|---|---|---|
| `ALLOWED_PATHS` | `()` (unrestricted) | Writable paths; everything else read-only (see above) |
| `SANDBOX` | `auto` | Enforcement policy: `auto` / `require` / `off` |
| `BRIDGE_TIMEOUT` | `600` | Per-command timeout (seconds) |
| `BRIDGE_CWD` | `$HOME` | Default working directory for commands |
| `BRIDGE_POLL` | `1` | Inbox polling interval (seconds, env only) |

## Security

Read this part.

- **Anyone or anything that can write to this folder can run arbitrary commands as your WSL user.** That is the entire feature — and the entire risk surface. Keep the folder out of synced/shared locations (Dropbox, OneDrive shared spaces, network shares).
- The bridge runs as your normal WSL user — no elevation, no root.
- **Scope it down**: set `ALLOWED_PATHS` in `bridge.conf` and install bubblewrap to make everything outside your chosen repos read-only at the kernel level (see the allowlist section above). Use `SANDBOX="require"` if you want fail-closed behavior.
- The sandbox restricts *writes*, not *reads* or *network*. An agent can still read files your user can read and reach the network. If that matters for your threat model, don't bridge that machine.
- Everything the agent ran is auditable: `archive/` holds every executed command, `bridge.log` holds the timeline.
- Point-in-time kill switch: close the console window, or `wsl -e pkill -f "bash runner.sh"`, or run `uninstall_autostart.bat`.
- `.gitignore` excludes `inbox/`, `outbox/`, `archive/`, logs, and heartbeat, so command history never lands in your git history.

## Troubleshooting

- **Heartbeat is stale / nothing executes** — the daemon isn't running. Start `start_bridge.bat` and look for errors in the console or `bridge.log`.
- **`bad interpreter` or CRLF weirdness** — shouldn't happen (the runner strips `\r`), but if you edited `runner.sh` on Windows with CRLF endings, run `wsl -e bash -c "tr -d '\r' < runner.sh > r.tmp && mv r.tmp runner.sh"`.
- **Commands hang** — each command is killed at `BRIDGE_TIMEOUT` (default 10 min). Interactive commands (anything that prompts) will hang until timeout; agents should use non-interactive flags (`-y`, `--no-input`, `DEBIAN_FRONTEND=noninteractive`).
- **Two daemons?** — the pidfile guard makes a second launch exit immediately; check `runner.pid`.
- **WSL not started at login** — the Startup-folder launcher runs `wsl.exe`, which boots your default WSL distro on demand. First heartbeat can take a few seconds after login.




## License

MIT — see [LICENSE](LICENSE).
