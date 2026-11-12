#!/usr/bin/env python3
"""
Fast DOM overflow analyzer.
Inspects all elements on the page across standard viewports and pinpoints
the exact DOM nodes extending past the document boundaries.
"""

import sys
import argparse
from playwright.sync_api import sync_playwright

DEFAULT_VIEWPORTS = [
    {"name": "01_mobile_se", "width": 375, "height": 667},
    {"name": "02_mobile_modern", "width": 390, "height": 844},
    {"name": "03_mobile_landscape", "width": 844, "height": 390},
    {"name": "04_tablet_portrait", "width": 768, "height": 1024},
    {"name": "05_tablet_landscape", "width": 1024, "height": 768},
    {"name": "06_desktop_laptop", "width": 1366, "height": 768},
    {"name": "07_desktop_fhd", "width": 1920, "height": 1080},
    {"name": "08_desktop_ultrawide", "width": 2560, "height": 1080},
]

def parse_args():
    parser = argparse.ArgumentParser(description="Analyze horizontal DOM overflows across viewports")
    parser.add_argument("--url", default="http://localhost:5180", help="Target URL (default: http://localhost:5180)")
    return parser.parse_args()

def switch_to_tab(page, tab_label):
    buttons = page.locator(f'header button:has-text("{tab_label}")').all()
    clicked = False
    for btn in buttons:
        try:
            if btn.is_visible():
                btn.click()
                clicked = True
                break
        except Exception:
            pass
    if not clicked:
        fallback = page.locator(f'button:has-text("{tab_label}")').first
        if fallback.is_visible():
            fallback.click()
    page.wait_for_timeout(300)

def main():
    args = parse_args()
    print(f"Scanning for layout overflows on: {args.url}\n")
    total_overflows = 0

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)

        for vp in DEFAULT_VIEWPORTS:
            context = browser.new_context(viewport={"width": vp["width"], "height": vp["height"]})
            page = context.new_page()
            try:
                page.goto(args.url, timeout=10000)
            except Exception as e:
                print(f"Failed to load {args.url}: {e}")
                sys.exit(1)
            page.wait_for_timeout(600)

            tab_buttons = page.evaluate("""() => {
                const btns = [];
                document.querySelectorAll('header button, nav button').forEach(b => {
                    const txt = b.innerText ? b.innerText.trim() : '';
                    if (txt && !btns.includes(txt) && txt.length < 30 && !txt.includes('Save') && !txt.includes('Tools')) {
                        btns.push(txt);
                    }
                });
                return btns;
            }""")

            if not tab_buttons:
                tab_buttons = ["Home"]

            for tab_label in tab_buttons:
                switch_to_tab(page, tab_label)

                res = page.evaluate("""() => {
                    const docWidth = document.documentElement.clientWidth;
                    const scrollWidth = document.documentElement.scrollWidth;
                    const offenders = [];
                    if (scrollWidth > docWidth) {
                        document.querySelectorAll('*').forEach(el => {
                            const r = el.getBoundingClientRect();
                            if (r.right > docWidth + 2) {
                                offenders.push({
                                    tag: el.tagName,
                                    cls: (el.className || '').toString().slice(0, 50),
                                    right: Math.round(r.right),
                                    overflow: Math.round(r.right - docWidth),
                                    snippet: (el.innerText || '').slice(0, 30).trim().replace(/\\s+/g, ' ')
                                });
                            }
                        });
                    }
                    return { docWidth, scrollWidth, hasOverflow: scrollWidth > docWidth, offenders };
                }""")

                if res["hasOverflow"]:
                    total_overflows += 1
                    diff = res["scrollWidth"] - res["docWidth"]
                    print(f"[!] OVERFLOW at {vp['name']} ({vp['width']}px) | Tab: '{tab_label}' | +{diff}px")
                    for o in res["offenders"][:5]:
                        print(f"    -> <{o['tag']} class='{o['cls']}'> extends +{o['overflow']}px | text: '{o['snippet']}'")

            context.close()
        browser.close()

    print(f"\nScan complete. Total overflow instances found: {total_overflows}")
    if total_overflows > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
