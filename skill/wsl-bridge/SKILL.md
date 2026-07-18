---
name: wsl-bridge
description: Run commands inside the user's local WSL (Windows Subsystem for Linux) via the cowork-wsl-bridge — either live MCP tools (wsl_run_command / wsl_bridge_status, possibly under an mcp__remote-devices__wsl-bridge__ prefix) or the file-based fallback folder connected to the session. Use this whenever the user asks to run, build, test, install, or inspect ANYTHING in their WSL environment, their Linux home, their local repos or projects, or says things like "on my machine", "in wsl", "my local environment", "check my repo", or "use the bridge" — even if they don't mention WSL or the bridge explicitly. Cloud Cowork sessions cannot execute commands on the user's machine directly; this bridge is the ONLY way, so reach for it any time local execution is implied.
---

# WSL Command Bridge

The user's Windows machine runs a daemon (`runner.sh`) inside WSL that watches a shared folder (the cowork-wsl-bridge repo — WSL sees it under `/mnt/c/...`). You execute commands by writing bash scripts into that folder via the device-bridge tools and reading results back. The user consented to this by installing the bridge. Full docs: https://github.com/Aryagarg23/CLAUDE_COWORK_WSL_INTERFACE

## Transport: prefer MCP, fall back to files

Look for tools named `wsl_run_command` / `wsl_bridge_status` — they may appear under a prefix like `mcp__remote-devices__wsl-bridge__` (the desktop app proxies the user's local MCP servers into the cloud session; exact prefix is client-dependent). If present, use them: same sandbox and allowlist as the file protocol, but real-time instead of ~10 s polling. Call `wsl_bridge_status` first to see the allowlist, then `wsl_run_command`.

If those tools aren't listed, don't assume the setup is broken — the MCP registration lives in the user's `claude_desktop_config.json` (installed via `mcp/install.sh` in the repo) and only takes effect in *new* sessions started after a desktop app restart. Fall back to the file protocol below without commentary; mention the MCP fast lane only if the user asks why commands feel slow.

## Prerequisites — check these first (file transport)

1. **Locate the bridge folder** among the session's connected folders: it contains `runner.sh`, `inbox/`, `outbox/`, and `heartbeat.txt`. If no connected folder matches, ask the user to add their bridge folder via "Add folder" in the desktop app.
2. **Read the folder's `CLAUDE.md` and `CLAUDE.local.md`** — the local file (gitignored, per-machine) documents this machine's specifics (username, project locations, allowlisted paths). Treat them as the source of truth over this skill.
3. **Check the daemon is alive**: stage and read `heartbeat.txt`; it is rewritten every second. If its `mtimeMs` is more than ~60 s old, the daemon is down — ask the user to double-click `install_autostart.bat` (or `start_bridge.bat`) in the folder, and don't queue commands until it's back.

## Sending a command

1. Pick a unique id: zero-padded counter + slug, e.g. `0007_run_tests`. List `archive/` and `inbox/` to find the highest existing number and continue from it.
2. Write a plain **bash script** (multi-line fine) to a local file, deliver it with `SendUserFile`, then `device_commit_files` it to `<bridge-folder>\inbox\<id>.cmd`.
3. Wait ~10–15 s (the daemon ignores files younger than 2 s, then polls every 1 s), then try staging `outbox/<id>.done`. If absent, retry every ~10 s. If nothing after ~3 min beyond expected duration, re-check the heartbeat.
4. When `<id>.done` exists, stage and read:
   - `outbox/<id>.out` — stdout
   - `outbox/<id>.err` — stderr
   - `outbox/<id>.meta` — `exit_code=`, `duration_s=`, `finished=`, `sandbox=`

## Rules of engagement

- **No interactive commands** — there is no TTY; prompts hang until timeout (default 600 s). Use `-y`, `--no-input`, `DEBIAN_FRONTEND=noninteractive`, and `git -c user.name=... -c user.email=...` instead of `git config --global`.
- **Batch aggressively** — each round-trip costs ~10 s. Combine related steps into one script with `echo "=== section ==="` separators instead of many small commands.
- **Long jobs** — launch detached (`nohup ... > <allowed-path>/job.log 2>&1 &`) and poll the log in later commands. Don't log to `/tmp`: it is private per-command and discarded when sandboxing is active.
- **Big outputs** — redirect to a file inside the bridge folder or an allowed path and send back a `head`/`tail`/`grep` summary.
- **Sandbox awareness** — check `sandbox=` in each `.meta`:
  - `bwrap`: filesystem is read-only outside the user's allowlist (`bridge.conf`) plus the bridge folder; writes elsewhere fail with `Read-only file system`.
  - `advisory`: not kernel-enforced — read `bridge.conf` and stay inside the allowed paths on your honor.
  - `blocked` (exit 126): the user requires enforcement but bubblewrap is missing — relay the install instruction from `.err`.
- **Never edit `bridge.conf`** — that's the user's policy file. If a task needs a path outside the allowlist, ask the user to add it.
- **Be conservative** — you run as the user's real account on their personal machine. No destructive commands (`rm -rf`, force-push, dropping data) unless the user explicitly asked for that exact action this session.
- **Cleanup** — you may delete `outbox/` and `archive/` entries for ids you created after reading them.

## Delegating to local Claude Code (if installed)

If the user has Claude Code installed in WSL, you can delegate entire agentic tasks to it through the bridge — useful when the work benefits from running locally (local MCP servers, venvs, toolchains, long jobs). Headless mode is the only mode that works (no TTY):

- It may not be on PATH in bridge shells — try `export PATH="$HOME/.local/bin:$PATH"` or check the folder's `CLAUDE.md` for the install location.
- Quick tasks: `cd <repo> && timeout 500 claude -p "task"` (stay under the bridge timeout).
- File-editing tasks: add `--permission-mode acceptEdits` — headless runs cannot answer permission prompts.
- Long tasks: `nohup claude -p "task" --permission-mode acceptEdits > <allowed-path>/job.log 2>&1 &`, then poll the log in later commands.
- Multi-turn: `claude -p --continue "follow-up"` or `--resume <session-id>`.
- Claude Code needs writable `~/.claude` and `~/.claude.json`; if the sandbox blocks them, ask the user to add those to `ALLOWED_PATHS` — its file edits remain confined to the allowlist either way.
