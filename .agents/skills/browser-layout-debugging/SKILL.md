---
name: browser-layout-debugging
description: Reproduce and measure local web layout differences with this project's Flatpak Firefox and Chrome installs. Use for CSS, responsive-layout, font-loading, or browser-engine discrepancies that need screenshots or exact DOM geometry; do not use for ordinary static code review that does not require a browser.
---

# Browser Layout Debugging

Use the real local build and both installed browser engines. Prefer numeric DOM evidence over judging alignment only from screenshots.

## Establish the artifact under test

1. Inspect the page's generated HTML and stylesheet order. Compare deployed and local first-party assets with hashes or `diff` when deployment drift is plausible.
2. Build the site with `python3 build.py build --force` when source or templates changed. Use `python3 build.py assets` only when the HTML is already current and only assets changed.
3. Serve `_site` over HTTP; do not use `file://`, because root-relative assets and service-worker behavior differ:

   ```sh
   python3 -m http.server 8765 --directory _site
   ```

4. Keep the server in a managed terminal session and stop it at handoff.

Opening a listening socket can be denied by the Codex sandbox with `PermissionError: Operation not permitted`. Retry the same server command with the required approval; this is not an application failure.

## Isolate external-resource failures

Before diagnosing layout, confirm every required stylesheet loaded and check the computed font. Firefox Flatpak may wait on or fail to load an external CDN resource while Chrome succeeds, producing a plausible but unstyled screenshot.

For a temporary offline test, mirror the referenced CSS under `_site` and rewrite only the ignored generated HTML to use it. Preserve relative font/image dependencies when typography or line wrapping matters. A copied stylesheet alone can make its relative `@font-face` URLs return 404 and change measurements.

Treat `_site` instrumentation as disposable:

- Never turn a CDN mirror or removed script tag into a source change unless the user requests it.
- `build.py assets` or a full build may remove temporary mirrored assets; recreate them before the next browser run.
- Run a full build before handoff so `_site` again represents the real project output.
- Confirm `git status` contains only intentional source changes.

## Launch the Flatpak browsers

Use fresh, task-specific profiles under `/tmp` to avoid changing the user's normal browser state.

### Firefox

Firefox's `--profile` directory must already exist. If it does not, Firefox shows “Your Firefox profile cannot be loaded” in GUI mode and can appear to hang in headless mode.

```sh
mkdir -p /tmp/blog-typst-firefox-profile
chmod 700 /tmp/blog-typst-firefox-profile
flatpak run --filesystem=/tmp org.mozilla.firefox \
  --headless --new-instance \
  --profile /tmp/blog-typst-firefox-profile \
  --window-size 1200,900 \
  --screenshot /tmp/page-firefox.png \
  http://127.0.0.1:8765/path/
```

For DOM measurement, retain `--window-size` and replace only the screenshot option with:

```sh
--remote-debugging-port=9223 http://127.0.0.1:8765/path/
```

Firefox exposes WebDriver BiDi at `ws://127.0.0.1:9223/session`, not at the server root. End the BiDi session normally before reconnecting; otherwise a subsequent `session.new` can fail.

### Chrome

The Flatpak wrapper can fail with `execlp failed` even when Chrome itself works. Launch the packaged browser binary directly:

```sh
flatpak run --filesystem=/tmp --command=/app/extra/chrome com.google.Chrome \
  --headless=new --no-sandbox --disable-gpu \
  --user-data-dir=/tmp/blog-typst-chrome-profile \
  --window-size=1200,900 \
  --screenshot=/tmp/page-chrome.png \
  http://127.0.0.1:8765/path/
```

For DOM measurement, retain `--window-size` and replace only the screenshot option with:

```sh
--remote-debugging-port=9222 http://127.0.0.1:8765/path/
```

Chrome exposes page targets through `http://127.0.0.1:9222/json/list`. Ignore extension background pages and connect to the target whose URL matches the page under test.

Flatpak browser startup and local debugging sockets commonly require approval. Ask for it directly when the sandbox blocks the command. Do not infer a browser bug from Flatpak's nested-sandbox warning alone.

## Measure layout

After starting a browser with its remote-debugging port, use the bundled probe. It requires a Node version with built-in `fetch` and `WebSocket` support (verified with Node 24 in this repository):

```sh
node .agents/skills/browser-layout-debugging/scripts/measure-layout.mjs \
  --browser chrome \
  --port 9222 \
  --url-substring /Blog/2026/ihep_cluster_passwordless/ \
  --selectors '#fn-3,#fn-4,ol'

node .agents/skills/browser-layout-debugging/scripts/measure-layout.mjs \
  --browser firefox \
  --port 9223 \
  --url-substring /Blog/2026/ihep_cluster_passwordless/ \
  --selectors '#fn-3,#fn-4,ol'
```

The output records viewport size, user agent, each matching element's rectangle, and selected computed styles. Add a comma-separated `--styles` value when the issue depends on other properties.

Measure at the same viewport width in both engines. Compare the invariant that expresses the bug, such as equal `x` coordinates, aligned right edges, equal widths, or a breakpoint state. Screenshots remain useful for visual review, but report the numeric delta when possible.

## Diagnose CSS containing blocks

For floated margin notes and percentage sizing, record the note, its closest block ancestor, the list or quote container, and the section. Percentage widths and margins resolve against the current containing block; moving identical markup into a list can therefore change its final geometry.

Also inspect logical list padding. Tufte CSS 1.8.0 declares only `-webkit-padding-start` for top-level lists; Firefox can fall back to its fixed user-agent padding while Chrome uses the percentage. Prefer a project-local standards-based override such as `padding-inline-start` instead of modifying the CDN stylesheet.

## Verify and clean up

1. Rebuild the real site output.
2. Repeat exact measurements in Firefox and Chrome with fresh profiles or cache-busting URLs.
3. Check relevant desktop and mobile breakpoints.
4. Stop HTTP and browser-debugging processes.
5. Run project checks and `git diff --check`.
6. Report browser versions, viewport, measured before/after invariant, build result, and any browser that still needs manual verification.
