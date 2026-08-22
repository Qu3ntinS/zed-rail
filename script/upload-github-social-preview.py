#!/usr/bin/env python3
"""Upload the ZedRail social preview via GitHub's web UI (Playwright).

GitHub has no public API for social preview uploads. Manual uploads often look
successful in Settings but the CDN blob stays 404 if the browser leaves the
page before the PUT to /upload/repository-images/ completes.

Usage:
  pip install playwright
  playwright install chromium
  python3 script/upload-github-social-preview.py --login
  python3 script/upload-github-social-preview.py
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_IMAGE = ROOT / "crates/zed/resources/brand/zedrail-social-preview.jpg"
DEFAULT_REPO = "Qu3ntinS/zed-rail"
STATE_DIR = Path.home() / ".local/state/zedrail-github"
STATE_FILE = STATE_DIR / "github-auth.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=DEFAULT_REPO)
    parser.add_argument("--image", type=Path, default=DEFAULT_IMAGE)
    parser.add_argument("--login", action="store_true", help="Sign in to GitHub and save session")
    parser.add_argument("--headless", action="store_true", help="Run browser headless (after --login)")
    return parser.parse_args()


def ensure_playwright():
    try:
        from playwright.sync_api import sync_playwright  # noqa: F401
    except ImportError as exc:
        raise SystemExit(
            "Playwright is required. Install with:\n"
            "  pip install playwright\n"
            "  playwright install chromium"
        ) from exc


def login(base_url: str, state_file: Path) -> None:
    from playwright.sync_api import sync_playwright

    state_file.parent.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=False)
        context = browser.new_context(viewport={"width": 1280, "height": 720})
        page = context.new_page()
        page.goto(f"{base_url}/login", wait_until="domcontentloaded")
        print("Sign in to GitHub in the browser window. Waiting for login…")
        page.wait_for_function(
            """() => !!document.querySelector('meta[name="user-login"]')?.content""",
            timeout=0,
        )
        username = page.evaluate(
            """() => document.querySelector('meta[name="user-login"]')?.content || ''"""
        )
        context.storage_state(path=str(state_file))
        browser.close()
        print(f"Saved GitHub session for @{username} to {state_file}")


def verify_cdn_url(url: str) -> bool:
    result = subprocess.run(
        ["curl", "-sfI", url],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode == 0 and " 200 " in result.stdout


def upload(repo: str, image: Path, state_file: Path, headless: bool) -> None:
    from playwright.sync_api import sync_playwright

    if not state_file.exists():
        raise SystemExit(f'Missing session file {state_file}. Run with --login first.')
    if not image.exists():
        raise SystemExit(f"Image not found: {image}")

    image = image.resolve()
    owner, name = repo.split("/", 1)
    settings_url = f"https://github.com/{owner}/{name}/settings"

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=headless)
        context = browser.new_context(
            storage_state=str(state_file),
            viewport={"width": 1280, "height": 720},
        )
        page = context.new_page()
        page.goto(settings_url, wait_until="domcontentloaded")

        if "login" in page.url:
            raise SystemExit("GitHub session expired. Run with --login again.")

        page.locator("xpath=//h2[normalize-space()='Social preview']").first.wait_for(
            timeout=60_000
        )
        page.locator("xpath=//h2[normalize-space()='Social preview']").first.scroll_into_view_if_needed()

        edit_button = page.locator("#edit-social-preview-button")
        if edit_button.count():
            edit_button.first.click(force=True)

        remove_image = page.get_by_text("Remove image", exact=False)
        if remove_image.count():
            print("Removing broken social preview…")
            remove_image.first.click(force=True)
            page.wait_for_timeout(1500)

        if edit_button.count():
            edit_button.first.click(force=True)

        file_input = page.locator("input#repo-image-file-input")
        file_input.first.wait_for(state="attached", timeout=30_000)

        print(f"Uploading {image} …")
        with page.expect_response(
            lambda response: (
                response.request.method == "PUT"
                and "/upload/repository-images/" in response.url
                and 200 <= response.status < 300
            ),
            timeout=60_000,
        ) as upload_info:
            file_input.first.set_input_files(str(image))
        response = upload_info.value
        print(f"Upload finished: {response.status} {response.url}")

        page.locator("input.js-repository-image-id").first.wait_for(state="attached", timeout=20_000)
        image_id = page.locator("input.js-repository-image-id").first.input_value().strip()
        if not image_id:
            browser.close()
            raise SystemExit("Upload did not produce a repository image id.")

        context.storage_state(path=str(state_file))
        browser.close()

    time.sleep(3)
    repo_page = subprocess.run(
        ["curl", "-sL", f"https://github.com/{owner}/{name}"],
        capture_output=True,
        text=True,
        check=True,
    )
    og_url = ""
    for line in repo_page.stdout.splitlines():
        if 'property="og:image"' in line or "property='og:image'" in line:
            start = line.find("content=")
            if start == -1:
                continue
            quote = line[start + 8]
            end = line.find(quote, start + 9)
            og_url = line[start + 9 : end]
            break

    if not og_url:
        raise SystemExit("Could not read og:image from repository page.")

    print(f"og:image = {og_url}")
    if verify_cdn_url(og_url):
        print("CDN verification passed (HTTP 200).")
    else:
        raise SystemExit(
            "Upload metadata was saved but the CDN image still returns an error. "
            "Try again with --login or upload zedrail-social-preview.jpg manually "
            "and wait until the preview thumbnail appears before leaving the page."
        )


def main() -> int:
    ensure_playwright()
    args = parse_args()

    if args.login:
        login("https://github.com", STATE_FILE)
        return 0

    upload(args.repo, args.image, STATE_FILE, headless=args.headless)
    return 0


if __name__ == "__main__":
    sys.exit(main())
