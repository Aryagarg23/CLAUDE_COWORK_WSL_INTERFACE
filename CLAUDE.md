# CLAUDE.md — how to use this bridge (instructions for AI agents)

This folder is a **command bridge into the user's local WSL environment**. If you are an AI agent (Claude Cowork or otherwise) with read/write access to this folder, you can execute bash commands inside the user's WSL by following the protocol below. The user has consented to this by installing and starting the bridge.

## Before sending anything

Read `heartbeat.txt`. It is rewritten every second by the daemon. If its timestamp is more than ~30 seconds old, the daemon is **not running** — tell the user to run `start_bridge.bat` (or `install_autostart.bat` for permanent setup) instead of queuing commands into the void.

## Sending a command

1. Pick a unique id: zero-padded counter + short slug, e.g. `0042_run_tests`. Check `archive/` and `inbox/` to avoid collisions.
2. Write a **plain bash script** (LF or CRLF both fine) to `inbox/<id>.cmd`. Multi-line scripts are fine. It runs with `bash` from the user's `$HOME` by default — `cd` wherever you need.
3. Wait, then poll for `outbox/<id>.done`. Typical round-trip is 2–5 seconds (the daemon ignores files younger than 2 s, then polls every 1 s). Poll every ~5 s; give up after ~3 min beyond the expected command duration and re-check the heartbeat.
4. When `<id>.done` exists, read:
   - `outbox/<id>.out` — stdout
   - `outbox/<id>.err` — stderr
   - `outbox/<id>.meta` — `exit_code=`, `duration_s=`, `finished=`

## Rules of engagement

- **Never write interactive commands.** There is no TTY. Use `-y`, `--no-input`, `DEBIAN_FRONTEND=noninteractive`, `git -c core.askpass=true`, etc. Interactive prompts hang until the 600 s timeout.
- **Batch aggressively.** Each round-trip costs seconds — combine related commands into one script with `echo "=== section ==="` separators rather than sending five tiny commands.
- **Long jobs:** default timeout is 600 s. For longer work, launch with `nohup ... > /tmp/job.log 2>&1 &` and poll the log file in later commands.
- **Big outputs:** redirect to a file and send back a `head`/`tail`/`grep` summary, or write output files into this folder so they can be staged/read directly.
- **Cleanup:** you may delete old `outbox/` and `archive/` entries for ids you created once you've read them.
- **Safety:** you are running as the user's WSL account on their personal machine. Be conservative: no destructive commands (`rm -rf`, force-pushes, dropping databases) unless the user explicitly asked for that specific action this session.
- **Access control:** the user may have set `ALLOWED_PATHS` in `bridge.conf`. When active (check `sandbox=` in each result's `.meta`): `sandbox=bwrap` means the filesystem is read-only outside the allowlisted paths — writes elsewhere fail with `Read-only file system`, and `/tmp` is private and discarded after each command (use a dir inside an allowed path for state that must survive between commands). `sandbox=advisory` means restrictions are NOT kernel-enforced — you are on your honor: only modify files under the allowed paths (read `bridge.conf` to see them). `sandbox=blocked` (exit 126) means the user requires enforcement but bubblewrap isn't installed — relay the install instruction from `.err` to the user. Never edit `bridge.conf` yourself; that file is the user's policy, not yours.

## Delegating to local Claude Code (if installed)

If Claude Code is installed in this WSL, entire agentic tasks can be delegated to it through the bridge — useful when work benefits from running *locally*: local MCP servers, venvs/toolchains, or long agentic jobs that shouldn't hold a bridge round-trip open. Headless mode is the only mode that works (no TTY):

- It may not be on PATH in bridge shells — try `export PATH="$HOME/.local/bin:$PATH"`.
- Quick tasks: `cd <repo> && timeout 500 claude -p "task"` (keep the timeout under the bridge's 600 s).
- File-editing tasks: add `--permission-mode acceptEdits` — headless runs cannot answer permission prompts.
- Long tasks: launch detached with output to a log under an allowed path, then poll the log in later commands:
  `nohup claude -p "task" --permission-mode acceptEdits > <allowed-path>/.claude-job.log 2>&1 &`
- Multi-turn: `claude -p --continue "follow-up"` (or `--resume <session-id>`).
- The sandbox applies to everything Claude Code does. It needs writable `~/.claude` and `~/.claude.json` (add them to `ALLOWED_PATHS` — with the user's permission); its file edits remain confined to the project allowlist like any other command.

## Known environment (this machine)

Machine-specific details (username, project locations, active allowlist) live in `CLAUDE.local.md` in this folder — it is `.gitignore`d so it never ships with the repo. **Read it if it exists.** If it doesn't exist yet, create it for the user by copying the template below and filling it in from observation (`whoami`, `ls ~`, `bridge.conf`):

```markdown
# CLAUDE.local.md — this machine (not committed)
- WSL user: `<user>`, host `<host>`, WSL2.
- Projects live in: <paths + short description of what's in them>
- Writable allowlist (bridge.conf): <paths>. Enforcement: <bwrap installed? advisory?>
- This folder from WSL: /mnt/c/<path>
- Claude Code: <installed? where?>
```
