# Pault
Pault is a local prompt library for macOS built with SwiftUI and SwiftData. It keeps prompts on-device and provides a main library window, menu bar access, and a global hotkey launcher.

## What it does
- Create and edit prompts (title + content).
- Parse `{{variable}}` placeholders in prompt content and surface editable variable fields with live preview.
- Organize with tags and mark favorites.
- Archive prompts and filter by recent, favorites, archived, or tag.
- Search by title, content, or tag.
- Copy resolved prompt content (including filled template variables) and quick-paste to the frontmost app.
- Access prompts from the menu bar popover.
- Use a global hotkey (⌘⇧P) to open the launcher.
- Show first-run onboarding for the three app surfaces.

## Platform
- macOS 15+ (menu bar app, global hotkey, SwiftData, pasteboard/accessibility integration).
- iOS is not implemented in this app target (see PaultCore for shared models).

## Docs
- Docs index: `docs/README.md`
- Architecture overview: `docs/ARCHITECTURE.md`
- Data model reference: `docs/DATA_MODEL.md`
- User guide: `docs/USER_GUIDE.md`
- Enterprise docs: `docs/enterprise/README.md`

## Repo layout
- `Pault/ContentView.swift`: main window split view and toolbar actions.
- `Pault/SidebarView.swift`: filters, search, and prompt list.
- `Pault/PromptDetailView.swift`: editor with inspector toggle.
- `Pault/InspectorView.swift`: tags, favorite/archive, timestamps.
- `Pault/MenuBarContentView.swift`: menu bar library and quick actions.
- `Pault/HotkeyLauncherView.swift`: global hotkey launcher.
- `Pault/PreferencesView.swift`: app preferences and login item.
- `Pault/Prompt.swift`: SwiftData prompt model.
- `Pault/Tag.swift`: SwiftData tag model.
- `Pault/TemplateVariable.swift`: SwiftData template variable model linked to prompts.
- `Pault/TemplateEngine.swift`: variable parsing, resolution, and sync logic.
- `Pault/TemplateVariablesView.swift`: variable input + resolved preview in the detail editor.
- `Pault/PaultApp.swift`: app entry point and SwiftData setup.
- `Pault/AppDelegate.swift`: menu bar + hotkey wiring.
- `PaultCore/`: shared model scaffolding (not integrated in the app target yet).

## Development
- Open `Pault.xcodeproj` in Xcode 15+ (SwiftData required).
- Build and run the `Pault` scheme.

## Notes
- Cleanup and tracking notes: `docs/NOTES.md`
