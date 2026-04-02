# Compliance and security audit checklist

This checklist captures the current behavior of the macOS app target and points auditors to code evidence.

## Data residency
- Core app data is stored locally in the app sandbox using SwiftData.
- Embedded attachments are stored locally on disk under Application Support.
- Evidence: `Pault/PaultApp.swift`, `Pault/Prompt.swift`, `Pault/Attachment.swift`, `Pault/AttachmentManager.swift`

## Network egress
- The app contains HTTP client logic for AI provider integrations and connection tests.
- Evidence: `Pault/Services/AIService.swift`

## Encryption at rest
- The app does not implement application-layer encryption for prompt content or exports.
- Credentials are stored in Keychain.
- Evidence: `Pault/Services/KeychainService.swift`, repository search for encryption routines

## Data in transit
- Prompt content may be transmitted to Anthropic, OpenAI, or Ollama when the user invokes AI workflows.
- Clipboard usage exposes copied prompt content to the macOS pasteboard.
- Evidence: `Pault/Services/AIService.swift`, `Pault/PromptService.swift`

## Permissions and user consent
- Global hotkey registration uses Carbon.
- Import/export and attachment selection use standard user-approved file panels.
- Referenced attachments use security-scoped bookmarks.
- Evidence: `Pault/GlobalHotkeyManager.swift`, `Pault/ExportService.swift`, `Pault/AttachmentsStripView.swift`, `Pault/AttachmentManager.swift`

## Retention and deletion
- No automatic retention policy is implemented.
- The app includes delete operations for prompts and a full data reset path in settings.
- Evidence: `Pault/PromptService.swift`, `Pault/PreferencesView.swift`

## Logging
- Errors and operational messages are written through Apple unified logging.
- No remote logging pipeline is implemented.
- Evidence: `Pault/PaultApp.swift`, `Pault/Services/AIService.swift`, `Pault/PromptService.swift`, `Pault/AttachmentManager.swift`

## Backup and restore
- The app includes built-in JSON export/import for prompts.
- Export/import is partial and does not preserve every model.
- Evidence: `Pault/ExportService.swift`, `Pault/PreferencesView.swift`, `docs/DATA_STORE.md`
