# User guide

## Getting started
- Launch Pault to open the main window.
- On first launch, Pault shows a short onboarding flow for the main library, menu bar access, and launcher.
- Press `⌘N` or click `+` to open the prompt launchpad.

## Create a prompt

### Main window
- Use the launchpad to create a prompt in one of four ways:
- Blank prompt.
- From template.
- Paste from clipboard.
- Generate with AI when Pro features are unlocked.

### Menu bar
- Open the menu bar popover and click `New` for a lightweight title-and-content sheet.

## Edit a prompt in text mode
- Select a prompt from the sidebar.
- Edit the title in the header and the body in the rich text editor.
- Changes save automatically after a short debounce.
- Use `{{variable_name}}` placeholders to create reusable variables.
- When variables exist, Pault shows editable variable fields and a resolved preview below the editor.
- Use the paperclip area to attach files. Images, media, PDFs, and common Office documents are supported.
- Use the toolbar overlay to save the current prompt as a reusable template.

## Switch to block mode
- In the prompt header, switch from `Text` to `Blocks`.
- You can start with an empty block canvas or, when the AI parse flow is available to you, ask Pault to parse existing text into blocks.
- In block mode, use `⌘[` to open the block library and `⌘]` to open the compiled preview.
- Free usage is limited to the first five blocks. Unlimited blocks are a Pro feature.
- Saving the canvas writes the compiled result back into the prompt.

## Use AI tools
- The sparkles control in the editor opens AI Assist.
- AI Assist includes prompt improvement, variable suggestions, tag suggestions, quality scoring, and a refinement loop.
- The run control streams provider output into the response panel and stores run history.
- A/B mode lets you maintain a `B` variant and compare run outputs when the relevant Pro features are unlocked.

## Organize prompts
- Use the sidebar for `Recently Used`, `All Prompts`, and `Archived`.
- Click the info button or press `⌘I` to open the inspector.
- In the inspector you can manage tags, mark a prompt as favorite, inspect timestamps, and open version history.
- When Pro smart collections are enabled, saved and AI-curated collections appear in the sidebar.

## Version history
- The inspector includes a collapsible `History` section.
- Pault stores prompt snapshots automatically as you edit.
- Open a version to inspect diffs against the current prompt.
- The history list also lets you select two entries and open the older one for comparison against the current prompt.

## Menu bar access
- Click the menu bar icon to open the mini library.
- Filter by `Favorites`, `All`, or `Archived`.
- Search prompts, expand a row, and use `Copy`, `Favorite`, `Archive`, or `Delete`.
- Use `New` to create a prompt without opening the full window.

## Global launcher
- Press the configured global hotkey to open the launcher. The default is `⌘⇧P`.
- Type to search prompts.
- Use `↑` and `↓` to move selection.
- Press `Return` to run the launcher’s default action.
- Press `⌘1` through `⌘9` to trigger one of the top results immediately.
- The launcher currently supports copy workflows only. If a prompt still has unfilled variables, the launcher will warn before copying.

## Preferences
- Open `Settings` from the app menu or the menu bar popover.
- `General` includes launch at login, dock icon visibility, default launcher action, and version-history retention.
- `Hotkey` lets you record a custom global shortcut and reset it to the default.
- `Appearance` controls font size, compact mode, and accent color.
- `Data` includes export, import, prompt/tag counts, and a destructive reset that clears prompts and tags.
- `AI` stores provider API keys in Keychain and lets you test Claude, OpenAI, and Ollama connectivity.

## Export and import
- Use `Settings > Data` to export all prompts to a JSON bundle.
- Import restores prompt records, tag associations, and template-variable values when the file format matches the current importer.
- Export is currently lossy for rich text, attachments, run history, version history, smart collections, templates, custom blocks, and block compositions.

## FAQ

### Why don’t I see a prompt anymore?
- Clear the search field.
- Check whether the prompt is archived.
- If you are viewing a smart collection, switch back to `All Prompts`.

### Why didn’t the launcher copy immediately?
- If the launcher default action is `Show options`, it opens the action step instead of copying.
- If the prompt still has empty variables, Pault keeps you in the action step so you do not silently copy unresolved placeholders by accident.

### Can I change the global shortcut?
- Yes. Open `Settings > Hotkey` and record a new shortcut.

### Can I back up my prompt library?
- Yes. Use `Settings > Data > Export All Prompts…` for a JSON backup, or back up the app container through standard macOS tooling.
