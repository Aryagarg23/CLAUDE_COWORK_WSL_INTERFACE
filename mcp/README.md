# MCP transport (fast lane)

The file-based bridge always works, but each round-trip costs ~10 s of
polling. This directory adds a second, faster transport: a **zero-dependency
MCP server** (pure Python 3 stdlib — no pip, no venv) that the Claude
desktop app launches inside your WSL and proxies into your cloud Cowork
sessions as real-time tools.

Same `bridge.conf`, same bubblewrap allowlist, same enforcement — **two
transports, one policy**. The file bridge remains the universal fallback
(and keeps its audit trail in `archive/`).

| | MCP transport | File bridge |
|---|---|---|
| Latency | ~instant | ~10 s per round-trip |
| Works for | Claude (desktop app proxy) | any agent that can write files |
| Needs | one config entry + app restart | folder connected to session |
| Audit trail | Claude chat log | `archive/` + `bridge.log` |

## Setup (once)

**Don't hand-edit `claude_desktop_config.json`.** It's not a scratch file —
it holds your real app state (window layout, folder grants, feature flags).
A careless paste can clobber it. Use the installer, which merges in just
the `mcpServers.wsl-bridge` key, takes a timestamped backup first, and
verifies nothing else changed:

```bash
# from WSL, inside the cloned repo
bash mcp/install.sh
```

It auto-detects the config path (`/mnt/c/Users/<you>/AppData/Roaming/Claude/claude_desktop_config.json`);
pass a path explicitly if it can't find it: `bash mcp/install.sh /path/to/claude_desktop_config.json`.

Then **restart the Claude desktop app once** — it needs to reload the config
file to pick up the new server entry. That's the only manual step.

Verified end-to-end (July 2026): after one restart, new Cowork sessions get
two live tools automatically, no per-session setup:

- **`wsl_run_command`** — execute bash in WSL (sandboxed, non-interactive,
  configurable timeout up to 600 s)
- **`wsl_bridge_status`** — report enforcement mode + allowlisted paths

They show up under a `remote-devices` / `wsl-bridge` prefix (client-dependent,
e.g. `mcp__remote-devices__wsl-bridge__wsl_run_command`) since the desktop
app proxies your local MCP servers into the cloud session.

### If it doesn't show up after restarting

The daemon and the MCP registration are independent — check both:

1. Confirm the config actually changed: `grep -A4 wsl-bridge` the config file
   the installer printed.
2. Fully quit the desktop app (not just close the window) and reopen it —
   some platforms keep it running in the tray/menu bar.
3. Start a **new** Cowork session — an already-open session won't pick up a
   server that registered after it started.

## Notes

- The server process itself runs unsandboxed (it must be able to *apply*
  the sandbox), but every command it executes goes through the same
  bubblewrap allowlist as the file bridge. Policy edits to `bridge.conf`
  apply immediately — the config is re-read before every command.
- No TTY: interactive commands hang until timeout. Agents are told to use
  non-interactive flags.
- Requires `python3` in your default WSL distro (any modern version).
- Test by hand: pipe JSON-RPC lines into it —
  `printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"0"}}}' '{"jsonrpc":"2.0","method":"notifications/initialized"}' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | python3 mcp/server.py`
