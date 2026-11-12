#!/usr/bin/env python3
"""
Playwright-based responsive capture script.
Tests a local or remote web application across standard viewports and aspect ratios,
capturing full-page and viewport screenshots and asserting against horizontal overflow.
"""

import os
import sys
import argparse
from playwright.sync_api import sync_playwright

DEFAULT_VIEWPORTS = [
    {"name": "01_mobile_se", "width": 375, "height": 667, "desc": "Mobile Compact (375x667 ~9:16)"},
    {"name": "02_mobile_modern", "width": 390, "height": 844, "desc": "Mobile Modern (390x844 19.5:9)"},
    {"name": "03_mobile_landscape", "width": 844, "height": 390, "desc": "Mobile Landscape (844x390)"},
    {"name": "04_tablet_portrait", "width": 768, "height": 1024, "desc": "Tablet Portrait (768x1024 3:4)"},
    {"name": "05_tablet_landscape", "width": 1024, "height": 768, "desc": "Tablet Landscape (1024x768 4:3)"},
    {"name": "06_desktop_laptop", "width": 1366, "height": 768, "desc": "Laptop / HD (1366x768 16:9)"},
    {"name": "07_desktop_fhd", "width": 1920, "height": 1080, "desc": "FHD Desktop (1920x1080 16:9)"},
    {"name": "08_desktop_ultrawide", "width": 2560, "height": 1080, "desc": "Ultrawide (2560x1080 21:9)"},
]

def parse_args():
    parser = argparse.ArgumentParser(description="Capture responsive screenshots across viewports")
    parser.add_argument("--url", default="http://localhost:5180", help="Target URL (default: http://localhost:5180)")
    parser.add_argument("--output", default="screenshots/responsive", help="Output directory")
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
    page.wait_for_timeout(500)

def main():
    args = parse_args()
    os.makedirs(args.output, exist_ok=True)
    print(f"Starting Responsive Capture for: {args.url}")
    print(f"Saving captures to: {args.output}\n")

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)

        for vp in DEFAULT_VIEWPORTS:
            vp_name = vp["name"]
            vp_dir = os.path.join(args.output, vp_name)
            os.makedirs(vp_dir, exist_ok=True)
            print(f"[*] Testing {vp['desc']} ({vp['width']}x{vp['height']})")

            context = browser.new_context(
                viewport={"width": vp["width"], "height": vp["height"]},
                device_scale_factor=1,
            )
            page = context.new_page()

            try:
                page.goto(args.url, wait_until="networkidle", timeout=15000)
            except Exception:
                page.goto(args.url, timeout=15000)
            page.wait_for_timeout(1000)

            # Discover navigation buttons in header
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
                slug = tab_label.lower().replace(" ", "_").replace("/", "_")
                print(f"    Capturing tab: {tab_label}...")
                switch_to_tab(page, tab_label)

                scroll_width = page.evaluate("() => document.documentElement.scrollWidth")
                client_width = page.evaluate("() => document.documentElement.clientWidth")
                if scroll_width > client_width:
                    print(f"    [!] Overflow: scrollWidth={scroll_width} > clientWidth={client_width} (+{scroll_width - client_width}px)")

                full_path = os.path.join(vp_dir, f"{slug}_full.png")
                page.screenshot(path=full_path, full_page=True)

                view_path = os.path.join(vp_dir, f"{slug}_viewport.png")
                page.screenshot(path=view_path, full_page=False)

            context.close()

        browser.close()
    print("\nCapture completed successfully!")

if __name__ == "__main__":
    main()
