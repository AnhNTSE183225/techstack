---
name: responsive-ui-audit
description: >-
  Use this skill when the user asks to test, audit, capture screenshots, or fix responsive design,
  mobile layout, tablet breakpoint overflows, or CSS wrapping issues on web applications using Playwright.
---

# Responsive UI Audit & Layout Debugging Skill

This skill provides an automated 5-phase runbook to verify, diagnose, pinpoint, resolve responsive layout overflow defects, and enforce custom dark-mode scrollbars, sliding layout animations, and balanced grid structures.

---

## 5-Phase Workflow Overview

1. **Verify (Multi-Viewport Capture)**: Run Playwright headless across 8 standard device viewports (compact mobile, modern mobile, landscape mobile, tablet portrait, tablet landscape, laptop, FHD, and ultrawide) to capture full-page and viewport screenshots.
2. **Identify (DOM Geometry Scan)**: Execute client-side DOM queries to detect `scrollWidth > clientWidth` and pinpoint the exact CSS classes and text snippets of overflowing elements.
3. **Fix (Responsive Tailwind / CSS & Balanced Layouts)**:
   - Apply responsive breakpoints and flex wrapping.
   - Use **Dynamic Flex Stretch** (`flex flex-wrap items-stretch` with `flex-1 min-w-[210px]`) to avoid awkward trailing items or gaping holes on odd-count items (e.g., 5 cards).
4. **Style Scroller & Sliding Transitions (MusicBotUI Standard)**:
   - **Custom Scroller**: Never leave default white/gray browser scrollbars on scroll areas. Always implement the 5px translucent rounded scrollbar (or `.no-scrollbar`).
   - **Sliding Tab Highlight**: When implementing tabs, use a sliding active pill indicator with `cubic-bezier(0.16, 1, 0.3, 1)` that slides smoothly from the old selection to the new selection, accompanied by `transition-colors duration-200` for hover states.
5. **Validate (Zero-Overflow Assertion)**: Re-run the automated overflow scanner to verify that zero elements overflow the viewport.

---

## Visual Design Standards

### 1. Sliding Active Tab Indicator (The Magic Pill Pattern)
Instead of abrupt background color toggles on click or flickering hover states (see [Hover Animation Issue](./resources/hover-animation-issue.png)):
- Position an absolute indicator beneath tab labels that dynamically transitions via `transform: translateX(...)` and `width` using Apple/iOS-style spring easing (`cubic-bezier(0.16, 1, 0.3, 1)`).
- See fixed implementation: [Sliding Tab Fixed](./resources/sliding-tab-fixed.png).

### 2. Odd-Numbered Grid Balancing (Avoiding Empty Voids)
Avoid rigid 2-column grids when displaying odd-numbered card collections (e.g. 5 providers), which leaves an empty void in the bottom-right (see [Uneven Layout Anti-Pattern](./resources/uneven-items-issue.png)).
- Instead, use `flex flex-wrap items-stretch gap-2.5` with `flex-1 min-w-[210px]`.
- Row 1 and Row 2 automatically stretch to fill 100% of the container (3 cards + 2 cards on tablet, 5 cards on desktop).
- See fixed implementation: [Balanced Providers Fixed](./resources/balanced-providers-fixed.png).

### 3. Mandatory Custom Scroller Pattern
When introducing scrolling on dark-themed apps, Windows Chromium browsers default to a jarring white/gray scrollbar (see [Bad Default Scrollbar](./resources/bad-default-scrollbar.png)).
Always implement the `MusicBotUI` custom scroller pattern in your root CSS (`index.css` / `styles.css`):

```css
/* Custom sleek scrollbar matching MusicBotUI pattern (avoids default white browser scrollbars) */
* {
  scrollbar-width: thin;
  scrollbar-color: rgba(148, 163, 184, 0.25) transparent;
}

*::-webkit-scrollbar {
  width: 5px;
  height: 5px;
}

*::-webkit-scrollbar-track {
  background: transparent;
}

*::-webkit-scrollbar-thumb {
  background: rgba(148, 163, 184, 0.25);
  border-radius: 9999px;
  transition: background 0.2s ease;
}

*::-webkit-scrollbar-thumb:hover {
  background: rgba(148, 163, 184, 0.45);
}

*::-webkit-scrollbar-button {
  display: none;
  width: 0;
  height: 0;
}

/* Utility to hide scrollbars while preserving touch/trackpad/wheel scrollability */
.no-scrollbar {
  scrollbar-width: none !important;
  -ms-overflow-style: none !important;
}

.no-scrollbar::-webkit-scrollbar {
  display: none !important;
}
```

---

## Standard Viewport Profiles

- **Mobile Compact**: `375 x 667` (~9:16)
- **Mobile Modern**: `390 x 844` (~19.5:9)
- **Mobile Landscape**: `844 x 390` (19.5:9 Landscape)
- **Tablet Portrait**: `768 x 1024` (3:4)
- **Tablet Landscape**: `1024 x 768` (4:3)
- **Laptop / HD**: `1366 x 768` (16:9)
- **Desktop FHD**: `1920 x 1080` (16:9)
- **Ultrawide**: `2560 x 1080` (21:9)

---

## Helper Scripts

- **Capture Screenshots Across All Viewports**:
  ```powershell
  python .agents/skills/responsive-ui-audit/scripts/capture_responsive.py --url <URL> --output <DIR>
  ```
  Helper script: [`capture_responsive.py`](./scripts/capture_responsive.py)

- **Scan & Pinpoint Overflowing Elements**:
  ```powershell
  python .agents/skills/responsive-ui-audit/scripts/detect_overflows.py --url <URL>
  ```
  Helper script: [`detect_overflows.py`](./scripts/detect_overflows.py)

---

## Resources & References

- Bad Default Scrollbar Anti-Pattern: [`resources/bad-default-scrollbar.png`](./resources/bad-default-scrollbar.png)
- Hover Animation Issue: [`resources/hover-animation-issue.png`](./resources/hover-animation-issue.png)
- Uneven 2-Column Void Issue: [`resources/uneven-items-issue.png`](./resources/uneven-items-issue.png)
- Sliding Tab Fixed Example: [`resources/sliding-tab-fixed.png`](./resources/sliding-tab-fixed.png)
- Balanced Providers Fixed Example: [`resources/balanced-providers-fixed.png`](./resources/balanced-providers-fixed.png)
- Detailed Layout & Breakpoint Guide: [`references/workflow-guide.md`](./references/workflow-guide.md)
