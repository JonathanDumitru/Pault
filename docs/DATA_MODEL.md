# Data model

This document describes the SwiftData models used by the current macOS app target.

## Prompt
- `id` (`UUID`): primary identifier.
- `title` (`String`): display title.
- `content` (`String`): current compiled prompt text.
- `attributedContent` (`Data?`): optional rich-text payload used by the text editor and richer clipboard copies.
- `isFavorite` (`Bool`): favorite flag.
- `isArchived` (`Bool`): archive flag.
- `tags` (`[Tag]`): prompt-tag relationships.
- `templateVariables` (`[TemplateVariable]`): variables parsed from `{{name}}` markers in `content`.
- `attachments` (`[Attachment]`): attached files.
- `versions` (`[PromptVersion]`): saved version history.
- `createdAt` (`Date`): creation timestamp.
- `updatedAt` (`Date`): last modification timestamp.
- `lastUsedAt` (`Date?`): last copy timestamp.
- `variantB` (`String?`): optional alternate text for A/B testing.
- `blockCompositionData` (`Data?`): serialized block-canvas snapshot.
- `editingModeRaw` (`String?`): persisted `text` or `blocks` mode.
- `blockSyncStateRaw` (`String?`): persisted sync state for block/text parity.

Notes:
- `content` is the source of truth for copy, run, search, export, and template-variable sync.
- Block editing persists back into `content` when the block canvas is saved.
- `lastUsedAt` is updated on copy to clipboard.

## Tag
- `id` (`UUID`): primary identifier.
- `name` (`String`): tag label.
- `color` (`String`): UI color key.
- `createdAt` (`Date`): creation timestamp.
- `prompts` (`[Prompt]`): backlink relationship.

## TemplateVariable
- `id` (`UUID`): primary identifier.
- `name` (`String`): placeholder token name.
- `defaultValue` (`String`): current stored fill value.
- `sortOrder` (`Int`): order of first appearance within the prompt.
- `occurrenceIndex` (`Int`): index among repeated uses of the same placeholder name.
- `prompt` (`Prompt?`): owning prompt.

## Attachment
- `id` (`UUID`): primary identifier.
- `filename` (`String`): original file name.
- `mediaType` (`String`): Uniform Type Identifier string.
- `fileSize` (`Int64`): file size in bytes.
- `storageMode` (`String`): `"embedded"` or `"referenced"`.
- `relativePath` (`String?`): on-disk path for embedded files.
- `bookmarkData` (`Data?`): security-scoped bookmark for referenced files.
- `thumbnailData` (`Data?`): generated image thumbnail when available.
- `sortOrder` (`Int`): display order in the attachment strip.
- `createdAt` (`Date`): creation timestamp.
- `prompt` (`Prompt?`): owning prompt.

## PromptVersion
- `id` (`UUID`): primary identifier.
- `prompt` (`Prompt?`): owning prompt.
- `title` (`String`): title snapshot.
- `content` (`String`): content snapshot.
- `savedAt` (`Date`): version timestamp.
- `changeNote` (`String?`): optional note.
- `isFavorite` (`Bool`): favorite-state snapshot.
- `snapshotData` (`Data?`): encoded tag and variable metadata snapshot.

## PromptRun
- `id` (`UUID`): primary identifier.
- `prompt` (`Prompt?`): nullable owning prompt.
- `promptTitle` (`String`): prompt title at run time.
- `resolvedInput` (`String`): prompt text sent to the provider.
- `output` (`String`): provider response.
- `model` (`String`): provider model identifier.
- `provider` (`String`): provider key such as `claude`, `openai`, or `ollama`.
- `latencyMs` (`Int`): observed latency in milliseconds.
- `inputTokens` / `outputTokens` (`Int?`): optional token accounting fields.
- `createdAt` (`Date`): run timestamp.
- `variantLabel` (`String?`): optional A/B or refinement label.
- `userRating` (`Int?`): optional score.
- `metadata` (`String?`): optional JSON metadata blob.

## CopyEvent
- `promptID` (`UUID`): copied prompt identifier.
- `timestamp` (`Date`): copy time.

`CopyEvent` is used for usage analytics and does not maintain a SwiftData relationship back to `Prompt`.

## SmartCollection
- `id` (`UUID`): primary identifier.
- `name` (`String`): collection title.
- `icon` (`String`): SF Symbol name.
- `sortOrder` (`Int`): sidebar ordering.
- `ruleType` (`CollectionRuleType`): `savedFilter` or `aiCurated`.
- `filterJSON` (`String`): encoded saved-filter definition.
- `promptIDs` (`[UUID]`): cached membership for AI-curated collections.
- `createdAt` (`Date`): creation timestamp.
- `lastRefreshed` (`Date?`): last refresh time.

## PromptTemplate
- `id` (`UUID`): primary identifier.
- `name` (`String`): template name.
- `content` (`String`): template body.
- `category` (`String`): grouping label used by the launchpad browser.
- `isBuiltIn` (`Bool`): seeded or user-created.
- `iconName` (`String`): SF Symbol name.
- `usageCount` (`Int`): number of prompts created from the template.
- `createdAt` / `updatedAt` (`Date`): timestamps.

## CustomBlock
- `id` (`UUID`): unique block identifier.
- `title` (`String`): block name.
- `category` (`String`): stored block category raw value.
- `valueType` (`String`): stored block value type raw value.
- `snippet` (`String`): block template text.
- `userCreated` (`Bool`): user-created flag.
- `createdAt` / `updatedAt` (`Date`): timestamps.

## Non-model block state

The block editor uses non-SwiftData structs and enums such as:
- `EditingMode`: `text` or `blocks`.
- `BlockSyncState`: `synced` or `diverged`.
- `BlockCompositionSnapshot`: encoded canvas state stored on `Prompt`.

Those types influence persistence, but they are stored inside `Prompt` rather than as top-level SwiftData entities.
