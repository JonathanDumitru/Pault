# Operational runbook

## Install
- Deploy the signed app bundle using your standard distribution method (PKG, MDM, or managed catalog).
- Launch once to initialize the SwiftData store and preferences.

## Uninstall
- Quit the app.
- Remove the app bundle.
- Optionally remove the container directory to delete all data (see `docs/DATA_STORE.md`).

## Reset preferences
- Preferences are stored in `UserDefaults` for bundle id `Jonathan-Hines-Dumitru.Pault`.
- To reset via Terminal:

```bash
defaults delete Jonathan-Hines-Dumitru.Pault
```

## Reset data
- Quit the app.
- Delete the app container directory (see `docs/DATA_STORE.md`).

## Collect logs
- Open **Console.app** and filter for process name `Pault`.
- Look for SwiftData load errors or hotkey registration failures.

## Verify core features
- Main window: create, edit, template variables, tag, favorite, archive.
- Menu bar popover: search, copy, paste, and create.
- Hotkey launcher: ⌘⇧P opens and performs copy/paste actions.
