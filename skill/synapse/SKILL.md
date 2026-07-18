---
name: synapse
description: Query or maintain Arya's Synapse knowledge-graph brains — the personal brain (claude.ai + Claude Code chat history digested into a navigable graph in ~/projects/synapse), the projects brain (~/projects_automated/brain), and the adaption research brain (~/projects/adaption-findings/brain). Use whenever Arya asks "what do I know / what have I thought about X", "check my brain / synapse", wants past conversations, decisions, or open threads recalled, wants a note filed into his brain, wants the graph browser opened, wants a new domain brain created, or wants the digest pipeline / brain build run or paused. All execution happens in WSL via the wsl-bridge.
---

# Synapse — Arya's knowledge-graph brains

Synapse turns chat history (claude.ai exports + finished Claude Code sessions) into
per-conversation JSON digests and a navigable graph, queryable over MCP. Engine:
`~/projects/synapse` (read its `CLAUDE.md` before working *on* it). All personal data is
local and gitignored — **never commit `data/`, `digests/`, or `graph/graph.json`**.

## Domains (separate brains, never mixed)

| MCP server name | Brain root | Contents |
| --- | --- | --- |
| `synapse-brain` | `~/projects/synapse` | Personal: full chat history |
| `synapse-projects` | `~/projects_automated/brain` | Portfolio/project knowledge |
| `synapse-adaption` | `~/projects/adaption-findings/brain` | Adaption research (kept out of the personal brain by charter) |

All three are registered in `~/projects_automated/.mcp.json` with `SYNAPSE_ALLOW_WRITE=1`.
`add_synapse_domain` (PortfolioMCP tool) scaffolds + registers a new one in one call.

## Querying from a Cowork session

Cowork can't speak stdio-MCP directly; two paths, both through the wsl-bridge:

1. **Delegate to local Claude Code** (full tool access):
   `cd ~/projects_automated && timeout 500 ~/.local/bin/claude -p "Using the synapse-brain MCP tools, ..." --allowedTools "mcp__synapse-brain__*"`
2. **Direct Python** against the read layer (no LLM, instant): the `brain/` package in
   the synapse repo — `models.py` (BrainQuery), `store.py` (loader), `query.py` (pure
   retrieval). Run short scripts with the repo's `.venv/bin/python`, cwd = brain root.

## The MCP tools (identical per domain)

- `brain_recall(text, categories, entities=["people:Alice","gear:X100"], modes, date_from/date_to, salience_min/max, temp, model_contains, backend, limit=20, sort=salience|date|relevance)` → matches with one-hop `neighbors`
- `brain_digest(id)` — full digest JSON, verbatim
- `brain_transcript(id, max_chars=20000)` — verbatim transcript, truncation marked
- `brain_neighbors(id, depth=1)` · `brain_hubs(min_categories=3)`
- `brain_categories()` · `brain_entities(kind)` · `brain_stats()` (incl. temp backlog)
- `brain_ingest_note(text, routing)` — files the note verbatim to `data/inbox/`; only exists when `SYNAPSE_ALLOW_WRITE=1`

API guarantee: tools retrieve, never synthesize — every result traces to a digest file
or transcript, and carries the `model` that wrote the digest plus a `temp` flag
(`temp: true` = produced by the free local backend, pending upgrade).

## The pipeline (manual, in the synapse repo)

```bash
.venv/bin/python scripts/split.py                                   # export → transcripts
.venv/bin/python scripts/digest.py --model haiku --confirm-seed --workers 6
.venv/bin/python scripts/build_graph.py && .venv/bin/python scripts/verify.py
```

Idempotent on re-runs. Cost gate: the Claude backend stops after 10 conversations
without `--confirm-seed`. Useful flags: `--upgrade` (redo `temp: true` digests),
`--refresh-model <substring>` (redo one model's work). Chats >~40K chars are chunked
automatically. Nightly cron ingests finished Claude Code sessions (free local backend
only). Tests: `.venv/bin/python -m pytest -q` (143 tests, synthetic fixtures).

## Passive building — the backend law

**Passive/automatic brain updates run on the local vLLM slave ONLY** (hard default; a
beefier backend happens solely via explicit per-domain `backend` config in
portfolio.json's synapse block — never chosen dynamically by an agent). Control via
PortfolioMCP tools: `synapse_status` (backlog, pause state, last build),
`synapse_build` (idle-only full build; also the hourly cron `synapse_build_cli.py`),
`stop_passive` / `pause_passive` / `resume_passive`. The vLLM slave runs ~16 requests
concurrently — parallelize (`--workers`), don't serialize.

## Browsing

`run_synapse_brain` (PortfolioMCP) serves the hub: one local page, domain dropdown over
separate per-domain graphs (`~/projects_automated/.synapse-hub`, static, offline). Or
per-repo: `cd graph && python3 -m http.server 8000`. Views: category graph, timeline,
entity graph, hubs; temp digests draw hollow.
