#!/usr/bin/env python3
"""
cowork-wsl-bridge — MCP transport (v1.2.0)

Zero-dependency stdio MCP server exposing sandboxed command execution
inside WSL. Launched by the Claude desktop app via wsl.exe, e.g.:

    "wsl-bridge": {
      "command": "wsl.exe",
      "args": ["-e", "python3", "/mnt/c/<path-to-repo>/mcp/server.py"]
    }

Enforces the SAME bridge.conf allowlist as the file-based bridge
(runner.sh): when ALLOWED_PATHS is set and bubblewrap is installed,
every command runs with the filesystem mounted read-only except the
allowlisted paths. Two transports, one policy.

Pure Python 3 stdlib — no pip, no venv, nothing to install.
https://github.com/Aryagarg23/CLAUDE_COWORK_WSL_INTERFACE
"""
import json
import os
import shutil
import signal
import subprocess
import sys

VERSION = "1.2.0"
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
SUPPORTED_PROTOCOLS = ("2024-11-05", "2025-03-26", "2025-06-18")
MAX_STREAM_CHARS = 40_000
DEFAULT_TIMEOUT = 120
MAX_TIMEOUT = 600


def log(msg):
    print(f"[wsl-bridge-mcp] {msg}", file=sys.stderr, flush=True)


# ---------------------------------------------------------------- config
def load_config():
    """Re-read bridge.conf (bash syntax) before every command — same
    hot-reload semantics as runner.sh. Parsed by bash itself so arrays
    and $HOME references behave identically to the file bridge."""
    allowed, sandbox, default_cwd = [], "auto", os.path.expanduser("~")
    conf = os.path.join(BASE, "bridge.conf")
    if os.path.isfile(conf):
        script = (
            'set -u; ALLOWED_PATHS=(); SANDBOX="auto"; BRIDGE_CWD=""; '
            'source <(tr -d "\\r" < "$1"); '
            'printf "%s\\n" "$SANDBOX" "${BRIDGE_CWD:-}"; '
            'for p in ${ALLOWED_PATHS[@]+"${ALLOWED_PATHS[@]}"}; do printf "%s\\n" "$p"; done'
        )
        try:
            out = subprocess.run(
                ["bash", "-c", script, "_", conf],
                capture_output=True, text=True, timeout=10,
            )
            lines = out.stdout.splitlines()
            if len(lines) >= 2:
                sandbox = lines[0].strip() or "auto"
                if lines[1].strip():
                    default_cwd = lines[1].strip()
                allowed = [l.strip() for l in lines[2:] if l.strip()]
        except Exception as e:  # config problems must never kill the server
            log(f"bridge.conf parse failed, running unrestricted-off: {e}")
            sandbox = "require"  # fail closed if we can't read policy
    override = os.environ.get("WSL_BRIDGE_SANDBOX")
    if override in ("auto", "require", "off"):
        sandbox = override
    return allowed, sandbox, default_cwd


# ---------------------------------------------------------------- execution
def run_with_timeout(argv, cwd, timeout):
    proc = subprocess.Popen(
        argv, cwd=cwd, start_new_session=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        stdin=subprocess.DEVNULL,
    )
    try:
        out, err = proc.communicate(timeout=timeout)
        return proc.returncode, out, err, False
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            pass
        out, err = proc.communicate()
        return 124, out or "", err or "", True


def execute(command, cwd=None, timeout=DEFAULT_TIMEOUT):
    allowed, sandbox_policy, default_cwd = load_config()
    cwd = cwd or default_cwd
    if not os.path.isdir(cwd):
        cwd = "/"
    timeout = max(1, min(int(timeout), MAX_TIMEOUT))

    have_bwrap = shutil.which("bwrap") is not None
    if allowed and sandbox_policy != "off":
        if have_bwrap:
            mode = "bwrap"
            argv = ["bwrap", "--ro-bind", "/", "/", "--dev", "/dev",
                    "--proc", "/proc", "--tmpfs", "/tmp",
                    "--bind", BASE, BASE, "--die-with-parent"]
            for p in allowed:
                p = os.path.expanduser(os.path.expandvars(p))
                if os.path.exists(p):
                    argv += ["--bind", p, p]
            argv += ["--chdir", cwd, "bash", "-c", command]
        elif sandbox_policy == "require":
            return {
                "exit_code": 126, "sandbox": "blocked", "timed_out": False,
                "stdout": "",
                "stderr": ("ALLOWED_PATHS is set with SANDBOX=require, but "
                           "bubblewrap (bwrap) is not installed in this WSL.\n"
                           "Ask the user to run: sudo apt install bubblewrap\n"
                           "(or set SANDBOX=\"auto\" in bridge.conf for "
                           "advisory-only restrictions)"),
            }
        else:
            mode = "advisory"
            argv = ["bash", "-c", command]
    else:
        mode = "none" if not allowed else "off"
        argv = ["bash", "-c", command]

    code, out, err, timed_out = run_with_timeout(argv, cwd, timeout)
    return {"exit_code": code, "sandbox": mode, "timed_out": timed_out,
            "stdout": out, "stderr": err}


def clip(s):
    if len(s) <= MAX_STREAM_CHARS:
        return s
    return (s[:MAX_STREAM_CHARS]
            + f"\n... [truncated {len(s) - MAX_STREAM_CHARS} chars — "
              "redirect to a file and grep/tail instead]")


# ---------------------------------------------------------------- tools
TOOLS = [
    {
        "name": "wsl_run_command",
        "description": (
            "Execute a bash command inside the user's local WSL environment. "
            "Runs sandboxed: the filesystem is read-only outside the user's "
            "allowlisted project paths (see wsl_bridge_status). Commands run "
            "non-interactively (no TTY) — use -y/--no-input style flags. "
            "Returns exit code, stdout, and stderr. Prefer combining related "
            "steps into one command; for jobs longer than the timeout, launch "
            "detached with nohup and poll a log file."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "Bash command or multi-line script to execute.",
                },
                "cwd": {
                    "type": "string",
                    "description": "Working directory (default: user's configured BRIDGE_CWD or home).",
                },
                "timeout_seconds": {
                    "type": "integer",
                    "description": f"Kill the command after this many seconds (default {DEFAULT_TIMEOUT}, max {MAX_TIMEOUT}).",
                },
            },
            "required": ["command"],
        },
        "annotations": {"readOnlyHint": False, "destructiveHint": True,
                        "idempotentHint": False, "openWorldHint": True},
    },
    {
        "name": "wsl_bridge_status",
        "description": (
            "Report bridge status: sandbox enforcement mode, allowlisted "
            "writable paths, default working directory, and versions. Call "
            "this first to learn what you are allowed to modify."
        ),
        "inputSchema": {"type": "object", "properties": {}},
        "annotations": {"readOnlyHint": True, "destructiveHint": False,
                        "idempotentHint": True, "openWorldHint": False},
    },
]


def tool_run_command(args):
    command = args.get("command", "")
    if not command.strip():
        return err_result("Empty command. Provide a bash command in 'command'.")
    r = execute(command, args.get("cwd"), args.get("timeout_seconds", DEFAULT_TIMEOUT))
    text = (
        f"exit_code={r['exit_code']}\n"
        f"sandbox={r['sandbox']}"
        + ("\ntimed_out=true (process killed — for long jobs use nohup + a log file)" if r["timed_out"] else "")
        + f"\n--- stdout ---\n{clip(r['stdout'])}"
        + f"\n--- stderr ---\n{clip(r['stderr'])}"
    )
    return {"content": [{"type": "text", "text": text}],
            "isError": r["sandbox"] == "blocked"}


def tool_status(_args):
    allowed, sandbox_policy, default_cwd = load_config()
    have_bwrap = shutil.which("bwrap") is not None
    if not allowed:
        effective = "none (ALLOWED_PATHS empty — unrestricted)"
    elif sandbox_policy == "off":
        effective = "off (policy disables sandbox)"
    elif have_bwrap:
        effective = "bwrap (kernel-enforced: read-only outside allowlist)"
    elif sandbox_policy == "require":
        effective = "blocked (bwrap missing, policy is fail-closed)"
    else:
        effective = "advisory (bwrap missing — restrictions not enforced)"
    lines = [
        f"wsl-bridge-mcp v{VERSION}",
        f"repo: {BASE}",
        f"user: {os.environ.get('USER', '?')}  host: {os.uname().nodename}",
        f"sandbox policy: {sandbox_policy}   bwrap installed: {have_bwrap}",
        f"effective enforcement: {effective}",
        f"default cwd: {default_cwd}",
        "writable paths:" if allowed else "writable paths: (everything — no allowlist)",
    ] + [f"  - {p}" for p in allowed] + [
        "Everything else on the filesystem is read-only to your commands."
        if allowed and have_bwrap and sandbox_policy != "off" else "",
        "Machine details: see CLAUDE.local.md in the repo folder (if present).",
    ]
    return {"content": [{"type": "text", "text": "\n".join(l for l in lines if l)}],
            "isError": False}


def err_result(msg):
    return {"content": [{"type": "text", "text": msg}], "isError": True}


# ---------------------------------------------------------------- JSON-RPC
def send(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def reply(msg_id, result):
    send({"jsonrpc": "2.0", "id": msg_id, "result": result})


def reply_error(msg_id, code, message):
    send({"jsonrpc": "2.0", "id": msg_id, "error": {"code": code, "message": message}})


def handle(msg):
    method = msg.get("method", "")
    msg_id = msg.get("id")
    is_notification = "id" not in msg

    if method == "initialize":
        requested = (msg.get("params") or {}).get("protocolVersion", "")
        version = requested if requested in SUPPORTED_PROTOCOLS else SUPPORTED_PROTOCOLS[-1]
        reply(msg_id, {
            "protocolVersion": version,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "wsl-bridge", "version": VERSION},
        })
    elif method == "ping":
        reply(msg_id, {})
    elif method == "tools/list":
        reply(msg_id, {"tools": TOOLS})
    elif method == "tools/call":
        params = msg.get("params") or {}
        name = params.get("name")
        args = params.get("arguments") or {}
        try:
            if name == "wsl_run_command":
                reply(msg_id, tool_run_command(args))
            elif name == "wsl_bridge_status":
                reply(msg_id, tool_status(args))
            else:
                reply_error(msg_id, -32602, f"Unknown tool: {name}")
        except Exception as e:
            log(f"tool {name} crashed: {e}")
            reply(msg_id, err_result(f"Tool execution failed: {e}"))
    elif is_notification:
        pass  # notifications/initialized, notifications/cancelled, etc.
    else:
        reply_error(msg_id, -32601, f"Method not found: {method}")


def main():
    log(f"wsl-bridge MCP server v{VERSION} starting (repo: {BASE})")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            reply_error(None, -32700, "Parse error")
            continue
        try:
            handle(msg)
        except Exception as e:  # never die mid-session
            log(f"handler error: {e}")
            if isinstance(msg, dict) and "id" in msg:
                reply_error(msg.get("id"), -32603, f"Internal error: {e}")
    log("stdin closed — exiting")


if __name__ == "__main__":
    main()
