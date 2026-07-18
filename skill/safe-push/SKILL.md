---
name: safe-push
description: Commit and push in any of Arya's WSL repos (~/projects/*, ~/projects_automated) the sanctioned way — via orchestrator/gitflow.py safe_push, never freehand git. Use whenever work in those repos needs committing or pushing, whenever Arya says "commit this", "push to github", or at the end of any agentic task that changed files in a portfolio repo.
---

# safe_push — the one sanctioned commit/push path

Freehand `git commit`/`git push` by agents is banned in Arya's portfolio (born
2026-07-16: agents were corrupting worktrees and diverging main). Use
`~/projects_automated/orchestrator/gitflow.py` instead — CLI or module — through the
wsl-bridge.

```bash
cd ~/projects_automated && .venv/bin/python orchestrator/gitflow.py \
  --repo <path> --kind <kind> --summary "imperative, <=72 chars" \
  [--scope <subsystem>] [--body "the why"] [--agent cowork-session] \
  [--paths a b c]        # empty = all changes
  [--allow-worktree]     # only if you OWN the worktree you're in
```

Kinds: `feat fix docs journal charter stats probe data chore`.
Module: `from gitflow import CommitIntent, safe_push`.

## What it does for you (don't work around it)

- Refuses to commit inside another session's worktree (`.claude/worktrees/...`).
- Fetches first and **refuses stale branches** (behind origin) — rebasing is a human
  decision. If refused, report it; don't force.
- Templates the message: `kind(scope): summary` + body + `Agent:` attribution.
- Protected-main repos (`git_policy: {"direct_to_main": false}` in portfolio.json) get
  auto-diverted to a fresh `agent/<kind>-<slug>` branch and that is pushed instead.

## Rules

- Exceptions where plain git is fine: repos outside the portfolio doctrine (e.g. the
  COWORK_WSL_INTERFACE bridge repo) — but prefer safe_push anywhere it works.
- Never `--force`, never rewrite history, never touch another branch's worktree.
- Personal-data law still applies: synapse `data/`, `digests/`, `graph/graph.json` are
  gitignored and must never be committed anywhere.
