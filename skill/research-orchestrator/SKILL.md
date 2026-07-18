---
name: research-orchestrator
description: Run Arya's scientific-method research machinery (AG23-tools/research-process, dogfooded on the adaption-findings investigation) — register pre-registered experiments, run the additive experiment loop, keep the ledger/DAG/graph/outcomes current, launch or nudge the standing researcher loop, or consult the lens/contract system. Use whenever Arya mentions experiments, hypotheses, probes, EXP files, the investigation, adaption / adaption-findings / the AutoScientist challenge, pre-registration, the researcher loop, lenses, or research orchestration. All execution happens in WSL via the wsl-bridge.
---

# Research orchestrator — the method as machinery

`~/projects/AG23-tools/research-process` is the *process* repo (lenses, method,
contracts, orchestration engine). Findings live in the consuming investigation repo —
currently `~/projects/adaption-findings/investigation/`. Every tool is generic via
`--repo <investigation dir>`.

## The one non-negotiable

**Pre-register the hypothesis and a falsifiable prediction BEFORE the run.** The lint
enforces it (`register.py --lint` refuses placeholders past `registered`). A surprising
result must never be rationalized into a confirmation — the verdict is scored against
the FROZEN prediction.

## The loop

QUESTION → LENS (pick one from `lenses/`: reductionist, mechanist, ethnographer,
falsifier, statistician, cartographer, adversary, economist, inversionist) →
HYPOTHESIS → PREDICTION (written down first, `method/hypothesis-template.md`) →
PROBE (one variable, one control) → RUN (receipt journaled before waiting) →
REPRODUCE (≥3× on unchanged input; effect below the noise floor is not a finding) →
CONCLUDE (confirmed/refuted/inconclusive vs the frozen prediction) → ADDITIVE NEXT
(builds only on locked conclusions).

Experiment states (ground truth = files, never a mutable field):
`registered → running → observed → reproduced → concluded`.

## The tools (`orchestration/`, all `--repo <investigation dir>`)

| Tool | Does |
| --- | --- |
| `register.py` | Scaffold `EXP-NNN` from template; `--lint` gate |
| `ledger.py` | EXP front-matter → `LEDGER.md` + `ledger.jsonl` |
| `dag.py` | Validate the additive DAG: no `builds_on` to a non-concluded node, no cycles |
| `graph_feed.py` | Emit `graph/graph.json` (synapse schema) from the clean folder only |
| `outcomes.py` | Concluded EXPs → agent-trace-outcome records (facts, not scores) |
| `synthesist.py` | Idle-cron interpreter: conclusions → `digests/state-of-investigation.md` |
| `nudge.py` | Queue a hint for the running researcher (`.nudges/inbox.md`) |
| `loop.py` | The spine: `next` (assemble researcher's move + drain nudges) · `ingest` (on conclude: ledger+dag+graph+outcomes+synthesist) |

`rp_common.py` is the single-source EXP parser — never parse EXP files by hand.
Launching the standing loop and mid-flight nudging: `orchestration/researcher-loop.md`.

## The three tiers (contracts/, read before acting in-tier)

**Sonnet judges → Haiku codes → vLLM executes.** Science consultant
(`science-consultant.md`): hypotheses, lens choice, probe design, interpretation —
writes no code. Coder (`coder.md`): writes+runs probe/verifier/analysis code — never
concludes. Local worker (`local-worker.md`, Qwen3-Coder-30B on vLLM): bulk
generate/run/label/digest — never decides. Default move at every tier is to offload
down; lock in yourself only after the tier below repeatedly fails.

## Governing principles (inherited, non-negotiable)

- Reverse-engineer the evaluator before optimizing — a mechanism is a finding, a score
  is not.
- **Local vLLM for all generative work**; verify with mock/estimate gates before
  anything metered ("verify before paid"). Free read-only observation is not a retry.
- Receipts: paid submissions journal to disk BEFORE waiting; killed observers resume,
  never resubmit (born of a real incident — ~11 duplicate paid jobs).
- Macro signal before niche noise.
- Research knowledge goes to the **synapse-adaption** brain, never the personal one.
- Commits via `projects_automated/orchestrator/gitflow.py safe_push` (safe-push skill).
