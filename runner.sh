#!/usr/bin/env bash
# ============================================================
#  cowork-wsl-bridge — runner.sh  (v1.1.0)
#
#  File-based command bridge between a cloud AI session
#  (Claude Cowork / any agent that can write to a Windows
#  folder) and your local WSL environment.
#
#  Watches inbox/ for *.cmd files, runs them in bash inside
#  WSL, writes results to outbox/. Executed commands are
#  archived in archive/.
#
#  v1.1.0: path allowlist (bridge.conf) with bubblewrap
#          filesystem sandboxing — everything outside
#          ALLOWED_PATHS is mounted read-only.
#
#  Start from Windows :  start_bridge.bat  (or install_autostart.bat once)
#  Start inside WSL   :  bash /mnt/c/<path-to-this-folder>/runner.sh
#
#  https://github.com/Aryagarg23/CLAUDE_COWORK_WSL_INTERFACE
# ============================================================
set -u

VERSION="1.1.0"
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INBOX="$BASE/inbox"
OUTBOX="$BASE/outbox"
ARCHIVE="$BASE/archive"
TMPDIR_B="$BASE/.tmp"
LOG="$BASE/bridge.log"
PIDFILE="$BASE/runner.pid"
POLL_INTERVAL="${BRIDGE_POLL:-1}"          # seconds between inbox scans

mkdir -p "$INBOX" "$OUTBOX" "$ARCHIVE" "$TMPDIR_B"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

# ---- config ------------------------------------------------
# bridge.conf is re-read before every command, so edits apply
# without restarting the daemon.
load_config() {
  ALLOWED_PATHS=()
  SANDBOX="auto"          # auto | require | off
  if [ -f "$BASE/bridge.conf" ]; then
    local cf="$TMPDIR_B/conf.$$"
    tr -d '\r' < "$BASE/bridge.conf" > "$cf"
    # shellcheck disable=SC1090
    . "$cf"
    rm -f "$cf"
  fi
  DEFAULT_TIMEOUT="${BRIDGE_TIMEOUT:-600}"  # seconds per command
  DEFAULT_CWD="${BRIDGE_CWD:-$HOME}"
}

# ---- single-instance guard ---------------------------------
if [ -f "$PIDFILE" ]; then
  oldpid="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
    echo "bridge already running (pid $oldpid) — exiting"
    exit 0
  fi
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

# ---- keep the log from growing forever ---------------------
if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 1048576 ]; then
  tail -n 200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

load_config
log "bridge v$VERSION started (pid $$, user $(whoami), host $(hostname), timeout ${DEFAULT_TIMEOUT}s)"
if [ ${#ALLOWED_PATHS[@]} -gt 0 ]; then
  if command -v bwrap >/dev/null 2>&1; then
    log "access control: ENFORCED via bubblewrap — writable: ${ALLOWED_PATHS[*]}"
  elif [ "$SANDBOX" = "require" ]; then
    log "access control: SANDBOX=require but bwrap missing — all commands will be REFUSED until 'sudo apt install bubblewrap'"
  else
    log "access control: ADVISORY ONLY (bwrap not installed — 'sudo apt install bubblewrap' for hard enforcement)"
  fi
else
  log "access control: none (ALLOWED_PATHS empty — commands are unrestricted)"
fi
log "watching: $INBOX"

# ---- execution ---------------------------------------------
# Runs the script; sets SANDBOX_USED for the meta file.
run_script() {
  local script="$1"
  if [ ${#ALLOWED_PATHS[@]} -gt 0 ] && [ "$SANDBOX" != "off" ]; then
    if command -v bwrap >/dev/null 2>&1; then
      SANDBOX_USED="bwrap"
      local args=(
        --ro-bind / /          # whole filesystem read-only...
        --dev /dev --proc /proc
        --tmpfs /tmp           # ...with a private writable /tmp
        --bind "$BASE" "$BASE" # bridge folder writable (results/artifacts)
        --die-with-parent
      )
      local p
      for p in "${ALLOWED_PATHS[@]}"; do
        [ -e "$p" ] && args+=(--bind "$p" "$p")   # allowlisted paths writable
      done
      local cwd="$DEFAULT_CWD"; [ -d "$cwd" ] || cwd="/"
      timeout "$DEFAULT_TIMEOUT" bwrap "${args[@]}" --chdir "$cwd" bash "$script"
      return $?
    elif [ "$SANDBOX" = "require" ]; then
      SANDBOX_USED="blocked"
      echo "bridge: ALLOWED_PATHS is set and SANDBOX=require, but bubblewrap (bwrap) is not installed." >&2
      echo "bridge: install it inside WSL with:  sudo apt install bubblewrap" >&2
      echo "bridge: (or set SANDBOX=\"auto\" in bridge.conf to run with advisory-only restrictions)" >&2
      return 126
    else
      SANDBOX_USED="advisory"
    fi
  else
    SANDBOX_USED="none"
  fi
  ( cd "$DEFAULT_CWD" 2>/dev/null || cd /
    timeout "$DEFAULT_TIMEOUT" bash "$script" )
}

while true; do
  # heartbeat so the cloud side can confirm the daemon is alive
  echo "$(date '+%Y-%m-%dT%H:%M:%S%z') pid=$$ user=$(whoami) v=$VERSION" > "$BASE/heartbeat.txt"

  for f in "$INBOX"/*.cmd; do
    [ -e "$f" ] || continue

    # Skip files modified within the last 2s (may still be syncing from Windows)
    now=$(date +%s)
    mt=$(stat -c %Y "$f" 2>/dev/null || echo 0)
    if [ $(( now - mt )) -lt 2 ]; then
      continue
    fi

    id="$(basename "$f" .cmd)"
    load_config
    log "executing: $id"

    # Normalize CRLF -> LF into a private copy inside the bridge folder
    # (kept under $BASE so it is visible inside the sandbox)
    tmp="$TMPDIR_B/$id.$$.sh"
    tr -d '\r' < "$f" > "$tmp"

    start_ts=$(date +%s)
    run_script "$tmp" > "$OUTBOX/$id.out" 2> "$OUTBOX/$id.err"
    ec=$?
    end_ts=$(date +%s)
    rm -f "$tmp"

    {
      echo "exit_code=$ec"
      echo "duration_s=$(( end_ts - start_ts ))"
      echo "finished=$(date '+%Y-%m-%dT%H:%M:%S%z')"
      echo "sandbox=$SANDBOX_USED"
    } > "$OUTBOX/$id.meta"

    # .done marker is written LAST so the cloud side never reads partial results
    echo "$ec" > "$OUTBOX/$id.done"

    mv "$f" "$ARCHIVE/$id.cmd"
    log "finished: $id (exit $ec, $(( end_ts - start_ts ))s, sandbox=$SANDBOX_USED)"
  done

  sleep "$POLL_INTERVAL"
done
