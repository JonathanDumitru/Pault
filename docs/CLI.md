# CLI

Pault includes a terminal companion named `pault` for read, copy, and run workflows against the same local prompt library used by the macOS app.

## Commands
- `pault list`: list non-archived prompts.
- `pault list --tag writing`: filter by tag name.
- `pault list --favorite`: show favorites only.
- `pault list --json`: output prompt ids and titles as JSON.
- `pault get "Prompt Title"`: print prompt content using a partial title match.
- `pault get "Prompt Title" --resolve --var topic=swift`: resolve `{{variables}}` before printing.
- `pault copy "Prompt Title"`: copy prompt content to the macOS clipboard.
- `pault copy "Prompt Title" --resolve --var topic=swift`: resolve variables before copying.
- `pault run "Prompt Title" --var topic=swift`: run a prompt against the first configured provider with a stored API key.

## Behavior notes
- The CLI reads the app’s SwiftData store directly from the Pault container on the same Mac.
- `list` excludes archived prompts.
- Title matching for `get`, `copy`, and `run` uses partial case-insensitive matching.
- `copy` writes plain text to the clipboard.
- `run` requires an API key configured in Pault Preferences and currently prefers the first available provider in this order: Claude, OpenAI, then Ollama.
