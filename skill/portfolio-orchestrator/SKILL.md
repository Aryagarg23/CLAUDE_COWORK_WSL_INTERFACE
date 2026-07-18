---
name: portfolio-orchestrator
description: Operate Arya's portfolio control plane (~/projects_automated, the PortfolioMCP server) — run autonomous fix loops on portfolio repos, queue/drain tasks, onboard new repos, run checks, query lessons/outcomes, manage charters, collect worker stats, or diagnose the orchestrator itself. Use whenever Arya mentions the portfolio, projects_automated, run_loop, the orchestrator, onboarding a repo, charters, the task queue, agent lessons/outcomes, or asks for autonomous work on any repo under ~/projects (AG23-tools, ag23-llm, agent-trace-outcomes, loop-test-journal, AryaGarg23_Website, exoplanet-radius-proposal, etc.). All execution happens in WSL via the wsl-bridge.
---

# Portfolio orchestrator — the AG23 control plane

`~/projects_automated` holds one MCP server class (`PortfolioMCP`,
`orchestrator/server.py`) orchestrating the portfolio. **No sub-project code lives
there** — projects are cloned under `~/projects/<name>` and registered in
`portfolio.json` (the single config file). Core primitive: `run_loop` =
act → check → record outcome → feed lessons back. Every session journals to the
loop-test-journal repo as agent-trace-outcomes records (Goal / Decision / Evidence /
Action / Outcome — never prompts).

**Read `AGENTS.md` in the repo first** — it is the map; `docs/index.md` is the
architecture; `charters/portfolio.md` is the root authority.

## Reaching it from Cowork

Via the wsl-bridge, two paths:

1. **Delegate to local Claude Code** (it picks up `.mcp.json` automatically):
   `cd ~/projects_automated && timeout 500 ~/.local/bin/claude -p "<task>" --allowedTools "mcp__ag23-portfolio__*"`
2. **CLIs directly** (no MCP client needed):
   - `.venv/bin/python orchestrator/loop_cli.py <project> "<goal>" [--backend auto|local|claude-code|gateway] [--attempts N] [--max-iterations N] [--allow-api] [--priority 1|2|3]`
   - `.venv/bin/python orchestrator/onboard.py <repo> [--clone] [--mutable] [--dry-run]`
   - `.venv/bin/python orchestrator/synapse_build_cli.py` (idle-only brain build)
   - `.venv/bin/python scripts/junk_sweep.py` (dry-run default)

## Key MCP tools (full table in README.md)

Read: `list_projects`, `project_status`, `query_lessons`, `list_tasks`, `doctor`,
`get_charter`, `synapse_status`, `vllm_status`, `chat` (ag23-llm gateway).
Act: `run_loop`, `run_checks`, `apply_edit`, `record_outcome`, `record_session`,
`queue_task` / `run_next_task`, `onboard_project`, `collect_stats`.
Governance: `request_feature` / `review_feature_requests` / `decide_feature_request`,
`derive_scope`, `suggest_scopes`, `charter_agent`, `charter_sweep`,
`install_charter_hooks`.

**If anything misbehaves, call `doctor` first** — it checks every dependency and says
exactly what to fix.

## Non-negotiables (root charter; full text in repo)

- **Priorities**: `run_loop`/`record_session`/`request_feature`/`queue_task` take
  `priority`: 1 = now, 2 = medium (default), 3 = async — `run_loop(priority=3)` queues
  instead of running; `run_next_task` drains.
- **Mutations** only where `allow_mutations: true` in portfolio.json; read-only projects
  still get proposal-mode loops. Nothing writes inside the control-plane repo except
  `portfolio.json` (onboarding), `stats/`, `charters/`, `docs/`.
- **Cost gate**: API backends need explicit `allow_api`; the local vLLM slave loops free.
  Backends: `claude-code` → `local` (vLLM at localhost:8000) → `gateway`, `auto`
  falls down the chain on failure.
- **Charter grounding**: workers get the governing charter + authority chain and must
  refuse conflicting goals (a refusal journals and stops, it doesn't retry).
- **Security floor**: no admin/PowerShell surfaces; never read outside the project
  workspace; check commands are denylist-screened.
- **Receipts**: paid/effectful API calls journal a durable receipt BEFORE waiting;
  resume via the receipt, never resubmit blind.
- **Tests are the gate**: `.venv/bin/python -m pytest -q` (all of it, always).
- Git: only via `orchestrator/gitflow.py safe_push` (see the safe-push skill).
  Suggestions: GitHub issues, not chat (see the file-issue skill).
- The local vLLM slave runs ~16 requests concurrently — parallelize local work.
