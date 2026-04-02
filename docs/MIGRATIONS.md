# Prompt format migrations

This document tracks the planned standalone `.prompt` file format. It is separate from the JSON export/import bundle that the app currently ships through `ExportService`.

## Current shipped import/export
- The live app exports a JSON bundle with a root `version` field and an array of prompt records.
- The importer currently expects that bundle format.
- This shipped format is intended for app backup and restore, not for full-fidelity interchange of every SwiftData model.

## Planned standalone `.prompt` format

### Version 1 (proposed)
- Single-prompt payload.
- Keys: `id`, `title`, `content`, `isFavorite`, `isArchived`, `createdAt`, `updatedAt`, `tags`, `templateVariables`.
- Optional encryption design remains proposal-only.

## Migration policy
- Always accept older bundle versions when practical.
- New keys should be optional with safe defaults.
- Prefer additive changes over key renames.
- Keep proposal docs clearly labeled when the format is not yet implemented.
