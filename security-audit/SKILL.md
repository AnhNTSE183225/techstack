---
name: security-audit
description: >-
  Three-tier security verification pipeline for AI-assisted ("vibe-coded") projects:
  (1) Gitleaks secret scanning, (2) Vibe Security 9-area review, and (3) Cloudflare
  heavy adversarial multi-phase security audit run last. Upstream skills are cloned
  into the gitignored `security-audit/vendor/` directory to preserve clean attribution
  and avoid committing third-party repositories.
---

# Security Audit Skill (3-Tier Defense-in-Depth Pipeline)

Every production-bound repository governed by `TECHSTACK` MUST pass this 3-tier security pipeline before launch and during every user-requested **Project Re-Evaluation**.

---

## 1. Upstream Tools & Attribution (Gitignored Local Vendor)

> [!CAUTION]
> **Anti-Plagiarism & VCS Hygiene Mandate:**
> `security-audit/vendor/` is strictly listed in `TECHSTACK/.gitignore`.
> **NEVER** commit, force-add (`git add -f`), or vendor third-party skill repositories into your own Git history. Always clone them locally into `security-audit/vendor/` using the setup scripts below.

| Tier | Tool / Skill | Upstream Repository | Purpose | Run Order |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1** | **Gitleaks** | [gitleaks/gitleaks](https://github.com/gitleaks/gitleaks) | Automated deterministic scan for hardcoded passwords, API keys, private keys, and tokens across source files & Git history. | **First** (fast fail) |
| **Tier 2** | **Vibe Security Skill** | [raroque/vibe-security-skill](https://github.com/raroque/vibe-security-skill) | Structured 9-area security audit targeting common AI coding blind spots (*Secrets Exposure, Database Access Control, Authentication, Rate Limiting, Payments, Mobile Security, AI/LLM Integration, Deployment Config, Input Validation*). | **Second** |
| **Tier 3** | **Cloudflare Security Audit Skill** | [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill) | Heavyweight multi-phase adversarial audit (*Reconnaissance → Coverage-Led Hunting → Independent Verification → Findings & Report*) where verifiers independently challenge hunter candidates. | **Last** (heavy final gate) |

---

## 2. One-Time Local Setup (Clone into Gitignored `vendor/`)

### Option A: Automated Setup Script
* **Windows (PowerShell):**
  ```powershell
  .\security-audit\setup-security-skills.ps1
  ```
* **Linux / macOS (Bash):**
  ```bash
  bash ./security-audit/setup-security-skills.sh
  ```

### Option B: Manual Clone Commands
```bash
mkdir -p security-audit/vendor
git clone --depth 1 https://github.com/raroque/vibe-security-skill.git security-audit/vendor/vibe-security-skill
git clone --depth 1 https://github.com/cloudflare/security-audit-skill.git security-audit/vendor/security-audit-skill
```

### Installing Gitleaks CLI
* **Windows:** `winget install Gitleaks.Gitleaks` (or download from [github.com/gitleaks/gitleaks/releases](https://github.com/gitleaks/gitleaks/releases))
* **Linux / macOS:** `brew install gitleaks` or `curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/main/scripts/install.sh | sh -s -- -b /usr/local/bin`

---

## 3. Execution Runbook (Run in Strict Order)

### Tier 1 — Gitleaks Secret Scan
Run against the target project root (both working directory and git history when `.git` exists):
```powershell
# Working directory (untracked + tracked files, excluding build artifacts)
gitleaks detect --source . --no-git --verbose

# Full Git commit history (if repository has commits)
gitleaks git --verbose
```
* **Pass Criterion:** Exit code `0` (`no leaks found`). Any confirmed secret MUST be rotated, removed from code, and moved to gitignored config (`config/local.yaml` or `.env`).

### Tier 2 — Vibe Security 9-Area Audit
1. Read `C:\GIT\TECHSTACK\security-audit\vendor\vibe-security-skill\vibe-security\SKILL.md` (and any referenced checklists inside `vibe-security\references\`).
2. Audit all **9 areas** against the target repo, marking N/A explicitly for unused surfaces (e.g., Payments or Mobile if not present):
   1. Secrets Exposure
   2. Database Access Control
   3. Authentication & Session Security
   4. Rate Limiting & Abuse Protection
   5. Payments & Webhooks *(or N/A)*
   6. Mobile Security *(or N/A)*
   7. AI / LLM Integration *(or N/A)*
   8. Deployment Config (CORS, TLS, Headers, Debug Modes)
   9. Input Validation & Injection Defense (SQLi, XSS, SSRF, Path Traversal)
3. Remediate all **Critical** and **High** findings immediately before advancing to Tier 3.

### Tier 3 — Cloudflare Security Audit Skill (Heavy Final Gate)
1. Read `C:\GIT\TECHSTACK\security-audit\vendor\security-audit-skill\skills\security-audit\SKILL.md` (and its phase guidance/validators).
2. Run the multi-phase audit workflow on the target repository:
   * **Phase 1 (Reconnaissance):** Map architecture, trust boundaries, auth boundaries, entry points, and coverage units.
   * **Phase 2 (Coverage-Led Hunting):** Systematically hunt vulnerabilities across each unit (auth, authorization/IDOR, persistence, SSRF/webhooks, client XSS, crypto/sessions, config).
   * **Phase 3 (Adversarial Validation):** Independently challenge every candidate finding (via fresh subagent or adversarial re-verification) to eliminate false positives before confirming severity.
   * **Phase 4–6 (Findings & Remediation):** Fix confirmed High/Medium/Critical vulnerabilities, verify with build + tests, and record the summary in the project's gitignored `CHECKLIST.md`.
