---
name: games-lab
description: Build or modify game prototypes in Arya's games-lab repo (~/projects/games-lab) — interactive pieces that make research digestible, destined to graduate to aryagarg23.com. Use whenever Arya mentions games-lab, a game prototype, boundless pong, the agent lobby / social sandbox, or wants a new interactive/explorable piece built. Always apply the presentation-identity skill (DESIGN.md rules) to anything visual. All execution happens in WSL via the wsl-bridge.
---

# games-lab — explorable figures, not an arcade

`~/projects/games-lab`. Games here prototype one thing: **interactive pieces that make
research digestible**. They graduate to aryagarg23.com as interactible writing pieces or
home-page pieces, so they wear the site's frozen design system from day one (see
`DESIGN.md` in the repo and the presentation-identity skill — default Tailwind is
someone else's choice, not a neutral one).

**The bar**: each prototype answers *what question does this let a reader feel the
answer to?* No research question → it's a toy; fine for scratch, but it doesn't
graduate.

## Structure & workflow

React + Vite + Tailwind v4, mirroring AryaGarg23_Website's frontend (minus
Supabase/Vercel/FastAPI). Note: active work happens on the `test` branch (also:
`test-model-visualizer`), not just `main` — check `git branch` before assuming.

Adding a game:
1. `frontend/src/app/games/<slug>/` — the component(s).
2. Register in `frontend/src/app/games/registry.tsx` (slug, title, description,
   lazy Component). Routes + home page pick it up automatically.

Run: `cd frontend && npm install && npm run dev`.
Existing games: `example-game` (template to copy), `boundless-pong`, `agent-lobby`
(Agent Developer Cockpit), `social-sandbox`.

## The agent workspaces

- `agent_workspace/room_N/` — sandboxed rooms for the agent-lobby experiment: model
  pairs writing HTML games and critiquing each other under fixed personas —
  room 1 Brutalist Architect, room 2 Playability/UX Designer, room 3 Style Guide
  Purist (HEX codes, radius zero, Space Grotesk, straight quotes), room 4 Clean
  Code & Performance Critic. Each room's README states its critique style; respect
  the persona when working in a room.
- `social_workspace/room_N/` — 15 rooms for the social-sandbox (agent pairs enacting
  human actions).

## Design rules (hard, from DESIGN.md — violations are bugs)

Radius 0 everywhere (`rounded-*` is a violation to fix). Borders not shadows (1px
rule-color hairlines). Cream ground `#eae4d6` / stone dark `#1c1c1c`, warm ink
`#282215` — never white/neutral-gray; muted text = ink at 0.4–0.6 opacity. Space
Grotesk only, weights 400/500. Color = register: blue `#3b42db` technical, hot
`#e85b30` warning/personal — never button colors. Both themes always, via semantic
tokens. Chart data uses the validated palette in fixed order. Motion: ~150–160ms UI
hovers, 320–360ms `cubic-bezier(.32,.72,0,1)` focus moves, 2.5–3.5s barely-perceptible
idle loops, `prefers-reduced-motion` respected. Delight comes from interaction and
motion, never visual chaos. Details are load-bearing — same care at 1rem and 1px.

Token source of truth: `AryaGarg23_Website/frontend/src/styles/moodboard/tokens.css`;
the Tailwind `@theme` port is in DESIGN.md. Known debt: the scaffold still has default
rounded Tailwind styling — fix on touch, don't propagate.
