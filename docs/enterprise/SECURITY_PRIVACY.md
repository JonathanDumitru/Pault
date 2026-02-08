# Security and privacy

## Data at rest
- Pault stores prompts locally using SwiftData in the app’s sandboxed container.
- The app does not implement its own encryption at rest. Use macOS full-disk encryption (FileVault) and device management policies if encryption is required.

## Data in transit
- The current app target performs no network requests and contains no telemetry or analytics code.
- Prompt data stays on-device unless a user copies it to the clipboard.

## Clipboard and paste behavior
- Copy actions write prompt content to the macOS clipboard (`NSPasteboard`).
- Paste actions in the launcher simulate ⌘V to the frontmost app. Clipboard contents can be read by other apps while present in the pasteboard.

## Permissions and system prompts
- Global hotkey registration uses the Carbon event manager.
- Simulated paste uses `CGEvent` via `AccessibilityHelper` and requires macOS Accessibility permission. The app automatically prompts for permission on the first paste attempt using `AXIsProcessTrustedWithOptions`.

## Logging
- The app uses Apple's unified logging framework (`os.Logger`) for error and informational messages (e.g., hotkey registration failures, accessibility permission status, preference changes).
- Logs are written to the system log and can be viewed in Console.app. There is no remote log shipping in the current app target.
