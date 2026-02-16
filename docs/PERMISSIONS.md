# Permissions and system prompts

## Accessibility
Pault uses simulated key events (`CGEvent`) to paste prompt content into the frontmost app. macOS requires Accessibility permission to allow this behavior.

**Automatic prompting:** The app checks permission using `AXIsProcessTrustedWithOptions` (via `AccessibilityHelper.swift`) on the first paste attempt. If permission has not been granted, macOS will display the system Accessibility permission dialog automatically. No manual setup is needed for most users.

To grant permission manually:
- Open **System Settings > Privacy & Security**.
- Select **Accessibility**.
- Enable access for Pault.

## Clipboard access
Pault uses `NSPasteboard` to copy prompt content. No special permission prompt is required, but clipboard contents may be visible to other apps while present in the pasteboard.

## Global hotkey
The global hotkey is registered using the Carbon event manager. No permission prompt is expected for registering the hotkey.
