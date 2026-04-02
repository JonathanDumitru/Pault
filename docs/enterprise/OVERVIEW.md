# Enterprise overview

This overview summarizes the current behavior of the macOS app for compliance and security review.

## Scope
- Pault is a macOS-only prompt workspace.
- Core data is stored locally with SwiftData.
- The app includes optional, user-triggered network egress for AI provider integrations.
- No remote analytics or remote log shipping are implemented in the current app target.

## Stored data categories
- Prompt titles, content, rich-text payloads, variables, tags, favorite/archive state, timestamps, and block-editor metadata.
- Prompt attachments and attachment metadata.
- Prompt version history, copy events, prompt-run history, templates, smart collections, and custom blocks.
- Preference values in `UserDefaults`.
- AI provider credentials in the user’s macOS Keychain.

## Data flows
- User edits save locally after a debounce or explicit block-editor save.
- Copy actions write prompt output to the macOS pasteboard and log local `CopyEvent` usage.
- AI-assisted features and prompt runs send prompt content to the selected provider endpoint when the user invokes them.
- Import and export move prompt data through user-selected files.

## Security posture
- Relies on macOS sandboxing and device-level protections such as FileVault for data at rest.
- Uses Keychain for provider credentials.
- Does not apply app-layer encryption to prompt content, attachments, or exported JSON bundles.
- Clipboard contents remain visible to other apps while present on the pasteboard.

## Audit evidence locations
- App entry point and schema: `Pault/PaultApp.swift`
- Prompt/editor flows: `Pault/ContentView.swift`, `Pault/PromptDetailView.swift`
- Menu bar and launcher: `Pault/AppDelegate.swift`, `Pault/MenuBarContentView.swift`, `Pault/HotkeyLauncherView.swift`
- AI networking: `Pault/Services/AIService.swift`
- Keychain storage: `Pault/Services/KeychainService.swift`
- Import/export: `Pault/ExportService.swift`
- Attachment handling: `Pault/AttachmentManager.swift`, `Pault/AttachmentsStripView.swift`
