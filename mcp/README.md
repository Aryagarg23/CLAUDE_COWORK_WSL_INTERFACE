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

1. Open your Claude desktop config file — on Windows:
   `%APPDATA%\Claude\claude_desktop_config.json` (create it if missing).
2. Add the server (adjust the repo path to where you cloned it):

```json
{
  "mcpServers": {
    "wsl-bridge": {
      "command": "wsl.exe",
      "args": ["-e", "python3", "/mnt/c/<path-to-repo>/mcp/server.py"]
    }
  }
}
```

3. Restart the Claude desktop app.

That's it. Sessions now get two tools:

- **`wsl_run_command`** — execute bash in WSL (sandboxed, non-interactive,
  configurable timeout up to 600 s)
- **`wsl_bridge_status`** — report enforcement mode + allowlisted paths

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
