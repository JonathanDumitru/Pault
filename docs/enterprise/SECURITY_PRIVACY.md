# Security and privacy

## Data at rest
- Pault stores app data locally using SwiftData in the app’s sandboxed container.
- Embedded attachment files are copied into a Pault-managed Application Support directory.
- The app does not implement its own encryption at rest for prompts, attachments, or exported bundles.
- Use FileVault and device-management controls if encryption-at-rest requirements apply.

## Credentials
- AI provider credentials entered in the app are stored in the user’s macOS Keychain.
- Credentials are not stored in the SwiftData database or export bundle.

## Data in transit
- The current app can make outbound network requests when a user invokes AI-assisted features, prompt runs, connection tests, or text-to-block parsing.
- Provider requests are sent to the configured Anthropic, OpenAI, or Ollama endpoint.
- No remote telemetry or remote analytics pipeline is implemented in the current app target.

## Clipboard behavior
- Copy actions write prompt content to the macOS pasteboard.
- Clipboard contents can be read by other apps while present in the pasteboard.

## File access
- Import and export use user-approved file panels.
- Large referenced attachments use read-only security-scoped bookmarks to reopen the original files later.

## Permissions and prompts
- Global hotkey registration uses Carbon and does not require a privacy prompt.
- The current copy workflow does not require Accessibility permission.
- File panels and bookmark-based file access are mediated by standard macOS user consent flows.

## Logging
- The app uses Apple unified logging (`os.Logger`) for local diagnostics.
- Logs can be inspected in Console.app.
- No remote log shipping is implemented in the current app target.
