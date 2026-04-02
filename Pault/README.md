# Pault

Pault is a macOS prompt workspace built with SwiftUI and SwiftData. It combines a local prompt library with a richer editor stack: template variables, attachments, version history, AI-assisted prompt workflows, and a visual block editor.

## What it does today
- Create prompts from scratch, from built-in templates, from clipboard text, or with AI-assisted generation.
- Edit prompts in text mode or block mode.
- Parse `{{variable}}` placeholders, store default values, and resolve them on copy and run.
- Save prompt versions automatically and inspect version history from the inspector.
- Attach files to prompts, including inline image insertion for supported image attachments.
- Organize with tags, favorites, archive state, and Pro smart collections.
- Access the same store from the main window, menu bar popover, and global launcher.
- Access the same local library from the bundled `pault` terminal companion.
- Run prompts against configured Claude, OpenAI, or Ollama providers when Pro features are unlocked.

## Current app surfaces
- Main window: full prompt management, launchpad, text editor, block editor, inspector, AI tools.
- Menu bar popover: search, copy, favorite, archive, delete, and quick prompt creation.
- Global launcher: keyboard-first search and copy actions.
- Preferences: general app settings, hotkey configuration, appearance, data import/export, and AI provider setup.

## Platform
- macOS 15+.
- iOS is not implemented in this app target.

## Docs
- Docs index: `docs/README.md`
- Architecture: `docs/ARCHITECTURE.md`
- Data model: `docs/DATA_MODEL.md`
- User guide: `docs/USER_GUIDE.md`
- CLI: `docs/CLI.md`
- Enterprise docs: `docs/enterprise/README.md`

## Repo layout
- `Pault/ContentView.swift`: main window and top-level prompt workflow.
- `Pault/PromptDetailView.swift`: text editor, block-mode switching, AI/run overlays, template saving.
- `Pault/BlockEditor/`: block editor models, services, and views.
- `Pault/PromptLaunchpadView.swift`: prompt creation launchpad.
- `Pault/MenuBarContentView.swift`: menu bar prompt access.
- `Pault/HotkeyLauncherView.swift`: global launcher.
- `Pault/PreferencesView.swift`: general, hotkey, appearance, data, and AI settings.
- `Pault/Prompt.swift`: primary SwiftData prompt model.
- `Pault/PromptService.swift`: CRUD, filtering, copy, tagging, version save orchestration.
- `Pault/Services/AIService.swift`: provider-backed AI operations.
- `Pault/ExportService.swift`: JSON import/export bundle support.

## Development
- Open `Pault.xcodeproj` in Xcode 15+.
- Build and run the `Pault` scheme.
