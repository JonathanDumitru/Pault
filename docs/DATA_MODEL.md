# Data model

This document describes the SwiftData models used by the macOS app target (`Pault/`). `PaultCore` ships a separate, expanded model set that is not wired into the app yet (see the note at the end).

## Prompt
- `id` (UUID): Primary identifier.
- `title` (String): Display title (can be empty).
- `content` (String): Prompt content.
- `isFavorite` (Bool): Favorite flag.
- `isArchived` (Bool): Archive flag.
- `tags` ([Tag]): Tag relationships (`nullify` delete rule).
- `templateVariables` ([TemplateVariable]): Variables parsed from `{{name}}` markers in `content` (`cascade` delete rule).
- `createdAt` (Date): Creation time.
- `updatedAt` (Date): Last update time.
- `lastUsedAt` (Date?): Last time the prompt was copied or pasted from any surface.

Notes:
- `updatedAt` is bumped on edits and tag/favorite/archive updates.
- `lastUsedAt` is set when any surface (main window, menu bar, or launcher) copies a prompt to the clipboard.
- `templateVariables` are synchronized from `content` by `TemplateEngine.syncVariables(...)`; removed markers delete stale variables.

## Tag
- `id` (UUID): Primary identifier.
- `name` (String): Tag label.
- `color` (String): UI color name (blue, purple, pink, red, orange, yellow, green, teal, gray).
- `createdAt` (Date): Creation time.
- `prompts` ([Prompt]): Backlink to prompts using this tag.

## TemplateVariable
- `id` (UUID): Primary identifier.
- `name` (String): Variable token name (for `{{name}}`).
- `defaultValue` (String): Current fill value used during resolve.
- `sortOrder` (Int): Display order matching first appearance in prompt content.
- `prompt` (Prompt?): Owning prompt relationship.

Notes:
- Variable extraction pattern currently accepts alphanumeric/underscore names (`\w+`).
- Copy/paste resolves only variables with non-empty values; empty values remain as `{{name}}`.

## PaultCore model note
`PaultCore` defines additional models (categories, variables, versions, workflows, usage logs). These are not currently referenced by the macOS app target, so they do not appear in the production data store yet.
