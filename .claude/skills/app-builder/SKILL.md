---
name: app-builder
description: Use at the start of ANY work in this area of the Klyro platform (reading, planning, or modifying code). Establishes the mandatory documentation-first workflow - read docs/ai before acting, locate files via MAP.md, make the smallest coherent change, and update the living docs afterwards.
---

# app-builder (general)

This is the **general orchestration skill** for this area of the Klyro platform. It applies to every task here: bug fixes, features, refactors, investigations, and questions about how things work. It exists so that each Claude Code session starts from the real, current state of the project instead of guessing.

The companion specialized skill (`app-builder-frontend`, `app-builder-backend`, or `app-builder-db` depending on the area) extends this one with domain-specific rules. **Always run this general skill first, then the specialized one.**

## Golden rule

> Read the docs, locate with the MAP, inspect the real source, make the smallest coherent change, then update the docs.

Documentation lives in `docs/ai/` relative to this area. It is a **living source of truth**: if reality and the docs disagree, the source code wins — fix the docs.

## Step 1 — Read before you act

Before making any change, read in this order:

1. `docs/ai/INDEX.md` — the entry point and table of contents. **Always read this first.**
2. `docs/ai/ARCHITECTURE.md` — how this area is structured and why.
3. `docs/ai/CURRENT-STATE.md` — what is built, in progress, or broken right now.
4. `docs/ai/MAP.md` — where things live (the file/module index).
5. `docs/ai/CHANGES.md` — what changed recently, to avoid undoing recent work.

Then read the relevant specialized docs for the area (see the specialized skill).

## Step 2 — Locate, don't guess

Use `docs/ai/MAP.md` to find the relevant files **before** searching the codebase randomly. If the MAP is missing an entry you needed, that is a documentation gap — add it once you find the file.

## Step 3 — Inspect the real source

Always open and read the actual source files before editing them. Never edit based on assumptions, the docs alone, or memory. The docs guide you to the file; the file is the truth.

## Step 4 — Make the smallest coherent change

- Make the **smallest change that fully solves the problem**.
- **Reuse** existing patterns, components, services, and utilities. Search for an existing solution before writing a new one.
- Do **not** introduce duplicate components, duplicate services, parallel patterns, or inconsistent architecture.
- Match the conventions in `docs/ai/CONVENTIONS.md` and the surrounding code (naming, structure, comment density, idioms).
- Do not modify application source code beyond what the task requires.

## Step 5 — Update the documentation

After any meaningful change, update the living docs so the next session is not misled:

- `docs/ai/CHANGES.md` — append a dated entry describing what changed.
- `docs/ai/TASKS-LOG.md` — log the completed work.
- `docs/ai/CURRENT-STATE.md` — update if a feature's status changed (new / in progress / done / broken).
- `docs/ai/DECISIONS.md` — record any technical decision and its rationale.
- `docs/ai/MAP.md` — update if files, modules, or routes were added, moved, or removed.
- `docs/ai/ENVIRONMENT.md` — (root area) update if Docker, environment variables, local setup, or deployment files changed.
- Plus the specialized docs the companion skill points to (`app-builder-db`).

Keep docs concise and accurate. They must reflect the **real current codebase**, not plans or assumptions.

## Step 6 — Report

At the end of the task, report:

- **Files changed** (with paths).
- **Decisions** made and why.
- **Risks** introduced or discovered.
- **Recommended next steps.**

## Checklist

- [ ] Read INDEX, ARCHITECTURE, CURRENT-STATE, MAP, CHANGES.
- [ ] Located target files via MAP.
- [ ] Inspected real source before editing.
- [ ] Made the smallest coherent change; reused existing patterns.
- [ ] Updated CHANGES, TASKS-LOG, CURRENT-STATE, DECISIONS, MAP as needed.
- [ ] Reported files, decisions, risks, next steps.
