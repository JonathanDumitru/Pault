# Operational runbook

## Install
- Deploy the signed app bundle through your standard distribution path.
- Launch once to initialize the SwiftData store, template seed data, preferences, and menu bar integration.

## Uninstall
- Quit the app.
- Remove the app bundle.
- Optionally remove the app container and Application Support attachment directory if you want a full data wipe.

## Reset preferences
- Preferences are stored in `UserDefaults` for bundle id `Jonathan-Hines-Dumitru.Pault`.

```bash
defaults delete Jonathan-Hines-Dumitru.Pault
```

## Reset data
- Quit the app.
- Delete the app container directory described in `docs/DATA_STORE.md`.
- If you want to fully remove embedded attachments, also remove the Pault attachment directory in Application Support.

## Collect logs
- Open `Console.app` and filter for process name `Pault`.
- Useful categories include lifecycle, preferences, AI, version history, attachments, analytics, and block-editor services.
- For AI issues, also capture the provider name, model, and whether the failure happened during a connection test, AI Assist, prompt run, or text-to-block parse.

## Verify core features
- Main window: create a prompt from the launchpad, edit title/content, copy, archive, tag, and reopen it.
- Variables: add `{{variables}}`, confirm variable rows appear, fill values, and verify resolved copy output.
- Attachments: add at least one file and confirm it appears in the attachment strip.
- Version history: make an edit, reopen the inspector, and verify the history count increases.
- Menu bar: search, copy, favorite/archive, and create a prompt from the quick sheet.
- Launcher: confirm the configured hotkey opens, search works, and copy succeeds.
- Settings: confirm hotkey recording, export/import, and AI connection tests behave as expected.

## Backup and restore checks
- Export all prompts from `Settings > Data`.
- Re-import the same file into a test profile or fresh data set.
- Confirm expected prompt count, tags, and template-variable values.
- Note that rich text, attachments, versions, runs, and block compositions are not preserved by the current exporter.
