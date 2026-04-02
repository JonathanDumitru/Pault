# Prompt file format (proposal)

This document describes a proposed standalone `.prompt` file format for future single-prompt interchange. It is not the same as the JSON bundle currently used by the app’s shipped export/import feature.

## Current shipped export/import
- The current macOS app exports a JSON bundle of prompts through `ExportService`.
- That bundle is the format used by `Settings > Data > Export All Prompts…` and `Import Prompts…`.
- The shipped bundle preserves prompt text, tags, and template-variable values, but it is not full-fidelity for every app model.

## Proposed standalone file extension
- `.prompt`

## Proposed payload
JSON dictionary with keys:
- `id` (`UUID` string)
- `title` (`String`)
- `content` (`String`)
- `isFavorite` (`Bool`)
- `isArchived` (`Bool`)
- `createdAt` (`TimeInterval`)
- `updatedAt` (`TimeInterval`)
- `tags` (`[String]`, optional)
- `templateVariables` (optional array), each with:
  - `name` (`String`)
  - `defaultValue` (`String`)
  - `sortOrder` (`Int`)

## Proposed encryption
- AES-GCM with a key derived from `SHA-256(password)`.
- No salt or stronger KDF is defined in the current proposal.

## Proposed behavior
- Export one prompt per file.
- Restore title, content, favorite/archive state, tags, and template variables.
- Treat `id` and timestamps as optional restore fields.

## Integration note
- If this format is implemented, include a `version` field and keep old keys stable for backward compatibility.
