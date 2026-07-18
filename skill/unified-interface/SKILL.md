---
name: unified-interface
description: Work in Arya's unified-interface repo (~/projects/unified-interface) — the design/spec repo for his stated ultimate goal, a "SWE Bloomberg terminal" where humans and models navigate graph representations of repositories. Use whenever Arya mentions the unified interface, the terminal, the graph layer, graph schema / graph/v1, PLAN-01, the builder contract, semantic zoom / level-of-detail, or designing/spec'ing this system. It is a documents-first repo: charter, contracts, clinical plans, cited research — treat spec edits as the real work. Execution via the wsl-bridge.
---

# unified-interface — the decades-scale chisel

`~/projects/unified-interface`. The goal (Arya's words: his ultimate goal in life): one
unified agentic interface — a *SWE Bloomberg terminal* where a human (and,
increasingly, a stronger model) looks only at **graph representations of repositories**
across abstraction layers, watches patterns and changes, and suggests edits; a better
model later takes charge of the same terminal without a redesign. The whitespace:
graphs exist as agent *backends* and as human *dashboards* — no one has unified them
into one cockpit with a designed authority handoff.

Docs-first repo: `CHARTER.md` (seven laws) → `contracts/` (builder.md,
graph-schema.md) → `PLAN-01-graph-layer.md` (current layer, clinical) → `research/`
(cited briefings). **Read the charter and builder contract before changing anything.**

## The seven laws (charter — charter wins over any tool/plan/habit)

1. Chisel inside-out, one layer at a time; nothing is one-shotted. Order: graph layer
   → data-logging layer → data-model pruning.
2. Research-backed before committed — a plan without citations is a draft.
3. One unified, polymorphic graph: code and knowledge are peers joined by a stable
   symbol-ID spine (SCIP-style). Schema changes are charter-level decisions.
4. Local-first: embedded storage, local rendering, local vLLM; server infra only at a
   proven, documented scale wall.
5. Provenance is mandatory on every node, edge, and suggestion (provenance-anchored
   diffs = layered agency).
6. Abstraction and change are first-class: semantic zoom over precomputed tiers and
   temporal/diff views ARE the product, not bolted on.
7. Name the open problems (stable layout across abstraction transitions, time×LOD
   stability, incremental deep dataflow) — build so a stronger model can attack them.

## Builder contract (contracts/builder.md — the tier ethos on top of research-process)

Sonnet architect writes no code: offload code to Haiku, bulk to vLLM. Design under a
research-process lens; freeze predictions before running; build only on locked,
reproduced conclusions; replan each layer from scratch with fresh research. Five
rules: never one-shot · research before build · protect the schema spine · provenance
or it didn't happen · local-first until a proven wall.

## graph/v1 schema (contracts/graph-schema.md — enforced by graph_contract.py)

Envelope, exactly five keys: `{profile, model, nodes, edges, skipped}`; `profile` ∈
personal | adaption | projects | investigation. Node required: `id`, `type`, `layer`
(code|knowledge|temporal), `level` (derived from type — builders cannot choose),
`label`, `summary`, `tags[]`, `provenance{source, extractor, model}`. Levels: 0 =
records/entities (chat, experiment, person, tool…), 1 = derived claims (finding,
hypothesis, decision, lesson…), 2 = groupings (category, repo); ≥3 reserved for the
code layer. Reliability superset enum: LIVE-VERIFIED | VERIFIED | CONFIRMED | REFUTED
| REPORTED | INCONCLUSIVE | JUDGMENT | OPEN | null, with a salience map where REFUTED
stays large (a locked verdict is high-information). Validators reject unknown fields;
coercions are logged in `skipped` as `coerced:`.

The machine-readable schema is `graph-schema.json`; `graph_contract.py` validates
before any builder writes. Known unifier context (PLAN-01 Part 1): three existing
pipelines (synapse chats / repo-docs / clean experiments) share one render contract;
the honest gaps are no semantic zoom, no abstraction hierarchy, no cross-repo overlay,
weak time views, low scale ceiling — that's the layer being built.

Reuses, never reinvents: the research-process engine drives investigation/decisions
(see the research-orchestrator skill). Memory pointer:
`arya-ultimate-goal-unified-agentic-interface`.
