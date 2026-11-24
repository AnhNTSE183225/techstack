---
name: project-checklist
description: >-
  Enforces a gitignored `CHECKLIST.md` compliance tracker in every repository governed
  by TECHSTACK. Run once at greenfield kickoff (from 0) and re-run whenever the user
  requests a full project re-evaluation. Rolls up every TECHSTACK rule plus the 3-tier
  security audit pipeline (Gitleaks -> Vibe Security -> Cloudflare Security Audit).
---

# Project Checklist Tracker Skill (`CHECKLIST.md`)

Because `TECHSTACK` enforces a comprehensive set of architectural, lifecycle, UI, observability, and security requirements, AI agents MUST maintain an explicit, gitignored `CHECKLIST.md` at the root of every project repository so zero requirements are silently skipped.

---

## Mandatory Rules

1. **Create `CHECKLIST.md` at Repo Root:** Copy [CHECKLIST.template.md](./CHECKLIST.template.md) into `<project-root>/CHECKLIST.md` and customize stack applicability (marking unused targets like Mobile as `N/A`).
2. **Always Gitignore `CHECKLIST.md`:** Immediately ensure `CHECKLIST.md` is listed in `<project-root>/.gitignore` so local audit tracking never pollutes Git history.
3. **Never Alter Existing Guides:** `CHECKLIST.md` is a **tracker**, not a replacement for `BACKEND_TECHSTACK.md`, `FRONTEND_TECHSTACK.md`, `VIBE_CODING_RULES.md`, or individual skill `SKILL.md` files.

---

## Two Trigger Modes

### Mode A: Greenfield Start (Building From 0)
1. At project kickoff, add `CHECKLIST.md` to `.gitignore` and generate `<project-root>/CHECKLIST.md` from [CHECKLIST.template.md](./CHECKLIST.template.md).
2. As each engineering phase completes, check off (`[x]`) verified items with brief evidence (e.g., binary size, test output, overflow count, scan exit code).
3. Before declaring the project production-ready, complete **Phase 6 (3-Tier Security Audit)** in order:
   1. Gitleaks
   2. Vibe Security 9-Area Audit
   3. Cloudflare Security Audit Skill (last)

### Mode B: On-Demand Re-Evaluation
Whenever the user asks to **re-evaluate** an existing repository:
1. Ensure `CHECKLIST.md` is in `.gitignore` and exists (create from template if missing, or reset/append a dated re-evaluation pass).
2. Re-verify every applicable item against the **current codebase on disk** (never trust stale checkmarks).
3. Run the full **Build → Responsive UI Audit → 3-Tier Security Audit** pipeline, record findings and fixes directly in `CHECKLIST.md`, and leave all local verification servers cleanly stopped (`stop.ps1` / `stop.sh`).
