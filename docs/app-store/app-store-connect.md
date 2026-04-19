# App Store Connect Metadata

Last updated: 2026-04-19

## Listing Fields

- **App Name:** `Pault`
- **Subtitle:** `AI Prompt Studio`
- **Primary Category:** `Productivity`
- **Secondary Category:** `Developer Tools`
- **Age Rating:** `4+`

### Keywords (100 chars max)

```
prompts,ai,llm,chatgpt,prompt engineering,workflow,developer,automation,productivity,templates
```

Character count: 93 (within 100-char limit)

## Promotional Text (170 chars max)

```
Try Pault Pro free for 7 days -- AI rewrites, prompt execution, version history, and analytics. Your prompts stay local.
```

## Description

```
Pault is the AI Prompt Studio for macOS — a fast, local-first workspace for building, running, and mastering your prompt library.

PAULT PRO
- AI Assist: Rewrite, improve, and shorten prompts with a single command (Cmd+Shift+I). Streams results live so you see the AI thinking.
- API Runner: Execute prompts directly against Claude, OpenAI, or your own models via a local Ollama instance (Cmd+Return). Results appear inline.
- Version History: Every save creates a version. Compare any two versions side-by-side with a synchronized diff view.
- Analytics: Track which prompts you use most, run history, token counts, and quality scores over time.
- Smart Collections: Auto-organize prompts by usage, quality score, recency, or any custom rule — always up to date.

FREE FEATURES
- Prompt Library: Unlimited local storage for all your prompts, organized with tags, favorites, and archive.
- Block Editor: Compose prompts visually with text, variable, and custom blocks. Compile to plain text for any AI tool.
- Menu Bar: Access your top prompts from the menu bar without switching windows.
- Global Hotkey: Open a launcher from anywhere with a customizable keyboard shortcut.
- Import & Export: Bring prompts in from Markdown or JSON, and export your library at any time.

PRIVACY FIRST
Everything is stored locally on your Mac. No account required for core features. AI features transmit only the prompts you explicitly run — never in the background.
```

## What's New (v1.0)

```
Welcome to Pault! First release.

Pault Pro includes AI Assist (streaming rewrites), API Runner (direct model execution), version history with diff view, usage analytics, and smart auto-organizing collections.

The free tier gives you an unlimited local prompt library with a block editor, menu bar launcher, global hotkey, and import/export.
```

## Privacy URL

```
https://pault.app/privacy
```

Source: `docs/legal/privacy-policy.md`

## Support URL

```
https://pault.app/support
```

## Marketing URL

```
https://pault.app
```

## Screenshot Lineup (6 shots — upload for each required macOS size)

Capture at 2560×1600. Light mode only. Clean app-only — no device frames, no text overlays.

1. **AI Assist** — Improve tab mid-stream showing rewritten text appearing live.
   Caption: `Rewrite prompts with AI in one command.`

2. **Block Editor** — Full canvas view with multiple block types and compiled preview visible.
   Caption: `Compose prompts visually with reusable blocks.`

3. **API Runner** — A prompt run in progress with streamed response visible inline.
   Caption: `Run prompts directly against any AI model.`

4. **Library Split View** — Full split view: sidebar + prompt list + detail pane with tags visible.
   Caption: `Your entire prompt library, always at hand.`

5. **Menu Bar Popover** — Popover floating above a visible macOS desktop (not blank).
   Caption: `Launch prompts from the menu bar, anywhere.`

6. **Analytics Dashboard** — Analytics view showing usage charts, token counts, and top prompts.
   Caption: `Track usage, quality, and run history over time.`

## ASC Questionnaire Answers

### Export Compliance (Encryption)

**Does your app use encryption?** Yes

**Exemption category:** The app uses HTTPS (TLS) for all network connections and does not implement custom encryption algorithms. This qualifies as an exemption under U.S. Export Administration Regulations (ECCN 5D002, License Exception ENC). No ERN (Encryption Registration Number) required.

**Answer in ASC:** Yes — select "My app uses only standard encryption" to qualify for the exemption.

### Advertising Identifier (IDFA)

**Does your app use the Advertising Identifier (IDFA)?** No

### Third-Party Content

**Does your app contain, display, or access third-party content?** No

### Content Rights

**Do you have the rights to all content in your app?** Yes — sole developer; all assets and code are original or licensed appropriately.

## Privacy Nutrition Labels

### Data Types Collected

| Data Type | Category | Linked to Identity | Used for Tracking | Purpose |
|-----------|----------|-------------------|-------------------|---------|
| Other User Content | Content — Other User Content | No | No | App Functionality |
| Other Data Types | Other Data — Other | No | No | App Functionality |

**Notes for ASC entry:**
- "Other User Content" covers prompt text transmitted to the AI proxy service when a user invokes AI Assist or API Runner.
- "Other Data Types" covers local app data (prompt library, settings).
- Neither type is linked to the user's identity or used for tracking.

## App Store Connect Steps

1. Open App Store Connect > My Apps > Pault > App Information.
2. Set Primary Category: Productivity, Secondary Category: Developer Tools.
3. Set Age Rating: 4+.
4. Open the App Store tab for the relevant version and paste:
   - Subtitle: `AI Prompt Studio`
   - Promotional Text (update at any time, no re-review required)
   - Description
   - Keywords
   - What's New text
5. Set Privacy Policy URL: `https://pault.app/privacy`
6. Set Support URL: `https://pault.app/support`
7. Set Marketing URL: `https://pault.app`
8. Upload 6 screenshots for each required macOS display size (typically 1280×800 and 2560×1600).
9. Complete the Content Rights and Advertising Identifier questionnaires.
10. Complete the Export Compliance questionnaire (select HTTPS-only exemption).
11. Enter Privacy Nutrition Labels as documented above.
