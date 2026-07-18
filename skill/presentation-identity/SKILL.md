---
name: presentation-identity
description: Arya's visual design system ("Presentation Identity — Arya Garg", pinned 2026-07-17) — apply it whenever building or styling ANYTHING visual for him: website pieces, games-lab prototypes, charts/plots/figures (matplotlib or web), slides, dashboards, HTML artifacts, or UI mockups. Use on any mention of design guide, style guide, color palette, chart colors, the site's look, brutalist styling, or when a deliverable will be seen on aryagarg23.com. Editorial-brutalist on warm paper; light AND dark always.
---

# Presentation Identity — Arya's design system

Pinned 2026-07-17. Identity statement: **editorial-brutalist on warm paper; one base
system, one licensed break per surface, one accent** (same structure as his wardrobe).
Purpose behind it: making research digestible for normies — sharp public front, delight
through interaction/motion, never visual chaos.

Canonical sources (WSL): `games-lab/DESIGN.md` (git: `test` branch; full rules +
Tailwind `@theme` port), `AryaGarg23_Website/frontend/src/styles/moodboard/tokens.css`
(token source of truth), `exoplanet-radius-proposal/styles/garg-{paper,stone,print}.mplstyle`
(chart registers), and the synapse inbox note `2026-07-17T224120Z-presentation-identity-design-guide.md`
(decisions + provenance). The claude.ai artifact "Presentation Identity — Arya Garg" is
the narrative original.

## Core tokens

| Token | Light (paper) | Dark (stone) |
| --- | --- | --- |
| Ground | cream `#eae4d6` | `#1c1c1c` |
| Ink | `#282215` | `#f1ede4` |
| Hairlines | `#c6b99f` | (same role, tuned) |
| Technical accent | blue `#3b42db` | `#6f76ec` |
| Warning / personal | hot `#e85b30` | `#d95526` |

Font: **Space Grotesk**, weights 400/500 only. Labels/eyebrows: uppercase, ~0.65rem,
`tracking-[0.14em]`, low opacity.

## Hard rules

- **Radius 0.** No rounded corners, ever. Borders (1px hairlines), not shadows.
- **Warm, not neutral.** Cream/stone grounds; muted text = ink at 0.4–0.6 opacity,
  never gray-500. Straight quotes; `tabular-nums` where digits column up.
- **Color = register, not decoration.** Blue for technical emphasis, hot for
  warnings/personal; neither is a button color (buttons: ink-on-paper/paper-on-ink).
- **Both themes, always**, via semantic tokens; tune per theme, don't invert (grain
  0.7→0.5 opacity on dark; chart grid alpha 0.55→0.65 so hairlines weigh the same).
- **Motion:** UI hovers ~150–160ms ease; focus moves 320–360ms
  `cubic-bezier(.32,.72,0,1)`; idle loops 2.5–3.5s, barely perceptible, subject
  anchored; respect `prefers-reduced-motion`.
- **Details are load-bearing.** A detail earns its place by fixing something real or
  rewarding a close reader; if it's the first thing you notice, it's decoration.

## Chart palettes (CVD/contrast validated — don't improvise)

- Categorical on cream, fixed order, never cycle past 4 (fold into "Other"):
  `#3b42db → #c2491d → #6f2f96 → #77701c`
- Categorical on stone: `#6f76ec → #d95526 → #a768c9 → #98912a`
- Reference lines (y=x, zero-residual): `#e85b30`, dashed.
- Sequential: brand blue. Diverging: blue↔burnt-orange, neutral midpoint —
  **replaces coolwarm everywhere** (open thread: exoplanet notebooks still on coolwarm;
  swap on touch).

Matplotlib: `plt.style.use("styles/garg-paper.mplstyle")` (site light) / `garg-stone`
(site dark) / `garg-print` (white ground, venue-safe — same series colors so figures
move between registers without re-encoding). Habits encoded in the style headers:
dense scatters alpha 0.3 s 10–15; titles state the question the plot answers, stats in
the title (r = 0.97); axis labels always carry units.

## What is NOT taste signal

Old library-default charts and the pre-2026-07-17 games-lab scaffold ("I never cared
for those"); the gritty Buckshot-roulette theme (rejected: "too playful for a public
sided front"). Don't read identity from them. Register: "pretty casual, but with a
tone of seriousness in work"; venue conventions win when actually publishing.
