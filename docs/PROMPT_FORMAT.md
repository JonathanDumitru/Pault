# Prompt file format (planned)

This document describes a **planned** `.prompt` file format for future export/import support. The current macOS app target does **not** implement export or import yet.

## File extension
- `.prompt`

## Payload (proposed)
JSON dictionary with keys:
- `id` (UUID string)
- `title` (String)
- `content` (String)
- `isFavorite` (Bool)
- `isArchived` (Bool)
- `createdAt` (TimeInterval, seconds since Unix epoch)
- `updatedAt` (TimeInterval, seconds since Unix epoch)
- `tags` ([String], optional tag names)

## Encryption (proposed)
- AES-GCM with a key derived from `SHA-256(password)`.
- No salt or additional key derivation is currently planned.

## Export/import behavior (proposed)
- Export is per prompt (one file per prompt).
- Import should restore title/content, favorite/archive, and tags.
- `id` and timestamps are optional restore fields (TBD).

## Integration notes
- If you plan to evolve the format, include a `version` field and keep old keys stable for backward compatibility.
