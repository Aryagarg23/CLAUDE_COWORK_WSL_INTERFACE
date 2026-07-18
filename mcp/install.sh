#!/usr/bin/env bash
# cowork-wsl-bridge — MCP transport installer
#
# Safely registers this repo's mcp/server.py in the Claude desktop app's
# config so Cowork sessions get real-time wsl_run_command / wsl_bridge_status
# tools instead of the ~10s file-polling fallback. Does NOT overwrite the
# config file — merges the mcpServers.wsl-bridge key in, preserving every
# other setting, and takes a timestamped backup first.
#
# Usage (from WSL):
#   bash mcp/install.sh
#   bash mcp/install.sh /custom/path/to/claude_desktop_config.json
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER="$BASE/mcp/server.py"

find_config() {
  if [ "${1:-}" != "" ]; then
    echo "$1"; return
  fi
  # Try the WSL user's own Windows profile first
  local guess="/mnt/c/Users/$(whoami)/AppData/Roaming/Claude/claude_desktop_config.json"
  if [ -f "$guess" ]; then echo "$guess"; return; fi
  # Fall back to searching all profiles
  local found
  found="$(find /mnt/c/Users/*/AppData/Roaming/Claude -maxdepth 1 -iname 'claude_desktop_config.json' 2>/dev/null | head -1 || true)"
  if [ -n "$found" ]; then echo "$found"; return; fi
  echo ""
}

CFG="$(find_config "${1:-}")"

if [ -z "$CFG" ] || [ ! -f "$CFG" ]; then
  echo "Could not find claude_desktop_config.json automatically." >&2
  echo "Pass its path explicitly: bash mcp/install.sh /mnt/c/Users/<you>/AppData/Roaming/Claude/claude_desktop_config.json" >&2
  exit 1
fi

echo "Config:  $CFG"
echo "Server:  $SERVER"

cp "$CFG" "$CFG.bak.$(date +%s)"
echo "Backup:  $CFG.bak.<timestamp> (created)"

python3 - "$CFG" "$SERVER" <<'PYEOF'
import json, sys
cfg_path, server_path = sys.argv[1], sys.argv[2]
with open(cfg_path) as f:
    cfg = json.load(f)

cfg["mcpServers"] = cfg.get("mcpServers", {})
cfg["mcpServers"]["wsl-bridge"] = {
    "command": "wsl.exe",
    "args": ["-e", "python3", server_path],
}

with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)

print(f"OK: mcpServers.wsl-bridge registered ({len(cfg)} top-level keys preserved)")
PYEOF

echo
echo "Done. Restart the Claude desktop app once for the config to load."
echo "After restart, new Cowork sessions will have wsl_run_command / wsl_bridge_status."
