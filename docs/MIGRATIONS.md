# Prompt format migrations (planned)

This document tracks compatibility decisions for the planned `.prompt` file format. Export/import is not implemented in the current macOS app target.

## Version 1 (proposed)
- No explicit `version` field (initial draft).
- JSON keys: `id`, `title`, `content`, `isFavorite`, `isArchived`, `createdAt`, `updatedAt`, `tags`, `templateVariables`.
- AES-GCM encryption with `SHA-256(password)` key derivation.

## Planned changes
- Add a `version` field at the root to enable forward compatibility.
- Preserve existing keys so older files remain readable.

## Migration policy
- Always accept older versions if possible.
- New fields should be optional with safe defaults.
- Avoid breaking key renames; prefer adding new keys instead.
