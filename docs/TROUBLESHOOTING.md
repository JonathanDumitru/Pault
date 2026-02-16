# Troubleshooting

## Global hotkey does not open the launcher
- Confirm the app is running (menu bar icon visible or app in Dock).
- Hotkey is fixed to ⌘⇧P in the current build; check for conflicts with other apps.
- If it still fails, check Console for logs from the Pault process about hotkey registration failures.

## Paste action does nothing
- Paste actions simulate ⌘V using `CGEvent` and require Accessibility permission.
- Open **System Settings > Privacy & Security** and grant access to Pault.
- Ensure the target app is frontmost when you run the paste action.

## Menu bar icon is missing
- If **Show dock icon** is disabled, the app runs as an accessory. Launch Pault directly once to restore the menu bar icon.
- If the icon still does not appear, quit and relaunch the app.

## Prompts appear missing
- Check the **Archived** filter in the sidebar.
- Clear the search field to ensure prompts are not filtered out.

## Changes are not saved between launches
- If SwiftData fails to load the persistent store, Pault falls back to an in-memory store.
- Look for messages like "SwiftData persistent store failed" in Console logs.
- If this happens, back up the container directory and reinstall or reset the app data.

## Copied text still contains `{{variable}}`
- Unfilled template variables are intentionally left unresolved on copy/paste.
- Open the prompt in the main window and set values in the **Variables** section.
