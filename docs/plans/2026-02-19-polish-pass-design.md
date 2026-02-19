# Polish Pass Design
**Date:** 2026-02-19  
**Status:** Approved

## Context

After the close-all-gaps sprint, a UX audit identified three remaining polish categories blocking a truly production-ready feel:

1. **Silent errors** — attachment add/delete failures are logged but never shown to the user
2. **Accessibility gaps** — `TagPillView` has no VoiceOver traits, menubar action buttons lack hints
3. **Magic numbers** — window sizes and the default hotkey key code are scattered as hardcoded literals

This pass closes those gaps without changing any functional behaviour.

---

## 1. StatusToast — Generalising CopyToast

### Problem
`CopyToast.swift` provides a green success toast but it's hardcoded. Four error paths in `AttachmentsStripView` log failures silently.

### Decision
Generalise `CopyToast` into a `StatusToast` supporting `.success`, `.error`, `.warning` styles. The existing `.copyToast()` modifier is preserved unchanged (no call-site churn).

### New API
```swift
enum ToastStyle { case success, error, warning }

// New modifier
.statusToast(isShowing: $showError, style: .error, message: "Couldn't add \(filename)")
```

### Errors to surface (in AttachmentsStripView)
| Location | Error | Toast message |
|----------|-------|---------------|
| `addFile(at:)` catch | File store/save failed | "Couldn't add '\(filename)'" |
| `deleteAttachment(_:)` catch | SwiftData save failed | "Couldn't delete attachment" |

### Errors kept silent (cosmetic / non-actionable)
- Thumbnail generation failure — image still shows a file-icon fallback
- `insertInline` image load failure — user can retry drag
- `RichTextEditor.syncContent` RTFD failure — plain text still syncs correctly

---

## 2. Accessibility

### TagPillView.swift (all instances — search, inspector, AI tabs)
```swift
// On the outer HStack / capsule:
.accessibilityLabel("\(name) tag")
.accessibilityAddTraits(onTap != nil ? .isButton : [])

// On the xmark remove button:
.accessibilityLabel("Remove \(name) tag")
```

### MenuBarContentView.swift — chevron expand/collapse
```swift
Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
    .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
    .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand") prompt actions")
```

### MenuBarContentView.swift — action buttons
```swift
Button(action: onCopy) { ... }
    .accessibilityHint("Copies prompt text to clipboard")

// Favorite toggle:
    .accessibilityHint(prompt.isFavorite ? "Removes from favorites" : "Adds to favorites")

// Archive toggle:
    .accessibilityHint(prompt.isArchived ? "Unarchives this prompt" : "Archives this prompt")
```

---

## 3. Constants.swift

### New file: `Pault/Constants.swift`
```swift
import Carbon
import CoreGraphics

enum AppConstants {
    enum Windows {
        static let mainDefault    = CGSize(width: 900, height: 600)
        static let aboutDefault   = CGSize(width: 400, height: 280)
        static let promptDefault  = CGSize(width: 700, height: 620)
        static let prefsDefault   = CGSize(width: 460, height: 360)
        static let menuBarDefault = CGSize(width: 320, height: 480)
    }
    enum Hotkey {
        static let defaultKeyCode:   UInt32 = 0x23  // P key
        static let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)
    }
    enum Timing {
        static let toastDuration: TimeInterval = 1.5
    }
}
```

### Files updated
| File | Change |
|------|--------|
| `PaultApp.swift` | 4 `.defaultSize(...)` calls → `AppConstants.Windows.*` |
| `PreferencesView.swift` | `.frame(width:height:)` + Reset button key code → `AppConstants` |
| `MenuBarContentView.swift` | `.frame(width:height:)` → `AppConstants.Windows.menuBarDefault` |
| `CopyToast.swift` | `1.5` duration → `AppConstants.Timing.toastDuration` |
| `GlobalHotkeyManager.swift` | `keyCodeP` can alias or be replaced by `AppConstants.Hotkey.defaultKeyCode` |

---

## Files Modified
- `Pault/CopyToast.swift` — generalise into StatusToast
- `Pault/AttachmentsStripView.swift` — add `@State` toast triggers + `.statusToast` modifier
- `Pault/TagPillView.swift` — add accessibility annotations
- `Pault/MenuBarContentView.swift` — add accessibility hints + use `AppConstants`
- `Pault/PaultApp.swift` — use `AppConstants.Windows`
- `Pault/PreferencesView.swift` — use `AppConstants`
- `Pault/GlobalHotkeyManager.swift` — use `AppConstants.Hotkey`
- `Pault/Constants.swift` — **new file**

---

## Verification
1. **StatusToast**: Add a file via drag-drop to a prompt, then trigger an error (e.g., duplicate or corrupt file) — red toast should appear and auto-dismiss
2. **Accessibility**: Enable VoiceOver (⌘F5), navigate to a tag pill — should announce "Tag name tag, button"; navigate to menubar row chevron — should announce expand/collapse hint
3. **Constants**: `grep -r "900, height: 600\|0x23\|1\.5" Pault/` should return zero results after the change (except inside Constants.swift itself)
4. **Tests**: `xcodebuild test` — all existing tests pass
