# Enterprise overview

This overview summarizes the app’s current behavior for compliance and security audits. It focuses on what is implemented today.

## Scope
- Pault is a local, macOS-only prompt library.
- Data is stored on-device using SwiftData.
- No network calls or telemetry exist in the current app target.

## Data types stored
- Prompt titles and content.
- Favorite and archived flags.
- Tags (name + color) and prompt-tag relationships.
- Timestamps (`createdAt`, `updatedAt`, `lastUsedAt`).

## Data flows
- User edits are saved locally after a short debounce.
- Copy and paste actions write prompt content to the macOS clipboard.
- Menu bar and hotkey surfaces read/write the same local store.

## Security posture (current)
- Relies on macOS sandboxing and device-level encryption (FileVault) for data at rest.
- Clipboard contents are visible to other apps while present in the pasteboard.
- No encryption is applied at the application layer.

## Audit evidence locations
- App entry point and SwiftData setup: `Pault/PaultApp.swift`.
- Menu bar and hotkey behavior: `Pault/AppDelegate.swift`, `Pault/GlobalHotkeyManager.swift`.
- Clipboard actions: `Pault/ContentView.swift`, `Pault/MenuBarContentView.swift`, `Pault/HotkeyLauncherView.swift`.
- SwiftData models: `Pault/Prompt.swift`, `Pault/Tag.swift`.
