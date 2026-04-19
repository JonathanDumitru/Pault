# App Store Screenshot Capture — XCUITest Workflow

## Overview

Screenshots are captured automatically via XCUITest using `ScreenshotTests.swift`. The test suite
injects realistic seed data (`ScreenshotDataSeeder`) via a `--screenshot-mode` launch argument and
captures 6 PNG attachments covering the locked hero-shot lineup.

---

## Locked Screenshot Lineup

| # | File name | Screen | Caption |
|---|-----------|--------|---------|
| 1 | `01-ai-assist.png` | AI Assist panel — Improve tab with mid-stream rewrite | "Smarter prompts, instantly. AI Assist rewrites and refines as you type." |
| 2 | `02-block-editor.png` | Block editor canvas with 5 semantic blocks | "Build prompts like Lego. Mix and match building blocks for perfect structure." |
| 3 | `03-api-runner.png` | API Runner with response history for SQL Optimizer | "Run directly from the library. Test any prompt against Claude, GPT, or Ollama." |
| 4 | `04-library-split-view.png` | Full 3-panel library: sidebar + list + detail | "Your entire prompt library, always at hand. Tagged, versioned, and searchable." |
| 5 | `05-menu-bar-popover.png` | Menu bar popover with recent prompts | "One click from anywhere. Launch and copy prompts without switching apps." |
| 6 | `06-analytics-dashboard.png` | Analytics dashboard with usage charts | "Know what works. Usage analytics reveal your most impactful prompts." |

---

## Prerequisites

Before running the screenshot tests:

1. **Retina display required** — Run on a 2x Retina display (MacBook Pro/Air, Retina iMac).
   The tests capture logical-point screenshots; the OS doubles them to 2560x1600.

2. **Disable display sleep** to prevent the screen going dark mid-run:
   ```bash
   caffeinate -d &
   ```

3. **Light Mode only** — Set macOS appearance to Light Mode before running:
   System Settings → Appearance → Light

4. **No personal data** — The seed data system injects fictional prompts via `--screenshot-mode`.
   Do not use a device with real production data in the app's SwiftData store. Use the simulator
   or a clean test device.

5. **Accessibility permissions** — Grant Xcode accessibility access in System Settings →
   Privacy & Security → Accessibility if prompted.

---

## Running the Tests

### Option A: Command line (recommended for CI / reproducible runs)

```bash
xcodebuild test \
  -project Pault.xcodeproj \
  -scheme Pault \
  -destination 'platform=macOS' \
  -only-testing:PaultUITests/ScreenshotTests \
  2>&1 | tail -30
```

### Option B: Xcode UI

1. Open `Pault.xcodeproj` in Xcode.
2. Select the **Pault** scheme and a macOS destination.
3. Open the Test Navigator (Cmd+6).
4. Expand **PaultUITests → ScreenshotTests**.
5. Click the run button next to `ScreenshotTests` to run all 6 tests.

---

## Extracting Screenshots

Screenshots are stored as `XCTAttachment` with `.keepAlways` lifetime inside the test result bundle.

### Option A: Xcode Test Results navigator

1. After tests complete, open the **Report Navigator** (Cmd+9).
2. Click the most recent test run.
3. Expand **PaultUITests → ScreenshotTests → testShot01_AIAssist** (etc.).
4. Under **Attachments**, right-click each PNG → **Save Attachment…**

### Option B: `xcresulttool` CLI

```bash
# List attachments in the result bundle
xcrun xcresulttool get \
  --path /path/to/Test.xcresult \
  --format json | python3 -m json.tool | grep -A3 "payload"

# Export a specific attachment by ID
xcrun xcresulttool export \
  --path /path/to/Test.xcresult \
  --id <attachment-id> \
  --output-path ~/Desktop/01-ai-assist.png
```

---

## Verifying Resolution

After extracting PNGs, verify each is 2560×1600:

```bash
sips -g pixelWidth -g pixelHeight ~/Desktop/01-ai-assist.png
# Expected output:
#   pixelWidth: 2560
#   pixelHeight: 1600
```

If the resolution is 1280×800, you are running on a 1x non-Retina display. Move to a Retina
display and re-run.

---

## Screenshot Naming Convention

Upload to App Store Connect using these exact file names:

```
01-ai-assist.png
02-block-editor.png
03-api-runner.png
04-library-split-view.png
05-menu-bar-popover.png
06-analytics-dashboard.png
```

---

## Seed Data Details

The `ScreenshotDataSeeder` creates:

- **10 realistic prompts** covering diverse use-cases (code review, API docs, SQL, meetings, etc.)
- **8 tags**: development, productivity, documentation, communication, database, product, agile, qa
- **4 PromptVersion entries** for "Code Review Assistant" (manual + AI Improve sources) — populates the version history panel
- **18 CopyEvent entries** across the top 5 prompts — populates the analytics charts
- **2 PromptRun entries** for "SQL Query Optimizer" with realistic query + analysis output

The AI streaming mid-state for Shot 01 is activated by `--screenshot-mode-ai-streaming`, which sets
`UserDefaults["screenshot_ai_streaming_active"] = true`. The AI Assist panel (or view model)
reads this flag to render a hardcoded partial rewrite instead of waiting for a live API call.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Tests fail — element not found | Run with `po app.debugDescription` in LLDB to inspect the live accessibility tree and adjust element queries in `ScreenshotTests.swift` |
| Resolution is 1280×800 | Move to a 2x Retina display |
| Charts are empty in Analytics shot | Increase `Thread.sleep` in `testShot06_AnalyticsDashboard` to give charts more time to render |
| Menu bar popover not visible | Confirm `AppDelegate` creates the status bar item and test device has a visible menu bar |
| Block editor shows plain text | Confirm seed prompt `editingModeRaw` is set to `"blocks"` and `blockCompositionData` is non-nil |

---

## ASC Upload Checklist

- [ ] All 6 PNGs extracted and renamed to naming convention above
- [ ] `sips` confirms 2560×1600 for each file
- [ ] Light Mode confirmed for all screenshots
- [ ] No personal data, API keys, or real user content visible
- [ ] Screenshots uploaded to the correct macOS app slot in App Store Connect
- [ ] Captions entered for each screenshot (see table in Locked Screenshot Lineup)
