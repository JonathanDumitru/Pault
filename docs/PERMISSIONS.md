# Permissions and system prompts

## macOS privacy prompts

Pault does not currently rely on Accessibility permission for its active copy workflow. The current build uses the pasteboard and provider APIs, not simulated `⌘V` paste.

## Clipboard access
- Pault writes copied prompt text to `NSPasteboard`.
- macOS does not show a special permission prompt for clipboard writes.
- Clipboard contents may be visible to other apps while they remain on the pasteboard.

## File access
- Import and export use standard open/save panels.
- Attachment import uses a user-selected file picker or drag-and-drop.
- Small attachments are copied into Pault-managed storage.
- Larger referenced attachments use security-scoped bookmarks so Pault can reopen the files later with read access.

## Network access
- AI features and provider connection tests make outbound network requests to the configured provider.
- Claude and OpenAI use vendor API endpoints.
- Ollama uses the configured base URL, which defaults to `http://localhost:11434`.

## Keychain access
- API keys entered in `Settings > AI` are stored in the user’s macOS Keychain via the Security framework.

## Global hotkey
- The global hotkey is registered through Carbon.
- No system privacy prompt is expected for hotkey registration.
