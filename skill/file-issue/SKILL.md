---
name: file-issue
description: File suggestions, deferred decisions, and "worth considering" ideas as GitHub issues on Arya's repos instead of writing them in chat. Use at the END of any task on Arya's WSL repos where you have a suggestion you're not implementing, whenever Arya says "file an issue" / "make a ticket", and for cross-repo agent feature requests in the portfolio.
---

# Suggestions are tickets, not chat

Arya, 2026-07-17: "i hate a chat message of it. its useless to me as a message."
Any suggestion, deferred decision, or improvement idea from ANY agent → a GitHub issue
on the repo it concerns. Chat gets at most one line: "filed #N".

## How (via the wsl-bridge; `gh` is authenticated in WSL)

```bash
cd <repo> && gh issue create \
  --title "Short, specific title" \
  --body "Actionable WITHOUT the originating chat's context: what, why, where in the code, acceptance criteria."
```

- Repo with no GitHub remote → file on `Aryagarg23/projects_automated` with the target
  repo named in the title.
- The body must stand alone — a reader with zero chat context should be able to act.
- One issue per suggestion; don't bundle unrelated ideas.

## Cross-repo feature requests (portfolio governance path)

When one project's agent wants a feature in ANOTHER portfolio repo, don't file a plain
issue — use the PortfolioMCP governance tools so the charter system adjudicates:
`request_feature` (files the issue with label `agent-feature-request`, arguing alignment
with the *target's* charter) → `review_feature_requests` / `decide_feature_request` on
the target side. Denials cite the charter clause; accepts on an unratified charter
auto-escalate to Arya.
