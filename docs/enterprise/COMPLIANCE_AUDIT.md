# Compliance and security audit checklist

This checklist captures the current behavior of the macOS app target and points auditors to evidence in the codebase.

## Data residency
- Data is stored locally in the app sandbox using SwiftData.
- Evidence: `Pault/PaultApp.swift`, `Pault/Prompt.swift`, `Pault/Tag.swift`.

## Network egress
- No network frameworks or HTTP clients are referenced in the app target.
- Evidence: repository search shows no `URLSession`, `URLRequest`, or network client usage.

## Encryption at rest
- The app does not implement application-layer encryption.
- Relies on macOS encryption (FileVault) and disk policies.
- Evidence: no crypto libraries or encryption routines in the app target.

## Data in transit
- No network transfer of prompt data in the current build.
- Clipboard usage exposes prompt content to the pasteboard.
- Evidence: `Pault/ContentView.swift`, `Pault/MenuBarContentView.swift`, `Pault/HotkeyLauncherView.swift`.

## Permissions
- Hotkey uses Carbon event manager (no prompt expected).
- Paste simulation uses `CGEvent` and may require Accessibility/Input Monitoring permission.
- Evidence: `Pault/GlobalHotkeyManager.swift`, `Pault/HotkeyLauncherView.swift`.

## Retention and deletion
- No retention policy is implemented.
- Deletion removes the prompt from the local store.
- Evidence: `Pault/ContentView.swift`, `Pault/MenuBarContentView.swift`.

## Logging
- Errors are printed to standard output; no remote logging.
- Evidence: `Pault/PaultApp.swift`, `Pault/GlobalHotkeyManager.swift`.

## Backup and restore
- No built-in export/import.
- Backups rely on OS or enterprise tooling.
- Evidence: `docs/DATA_STORE.md`.
