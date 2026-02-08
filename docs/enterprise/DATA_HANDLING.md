# Data handling

## Stored data
Pault stores:
- Prompt title and content.
- Favorite and archived flags.
- Tags (name + color) and prompt-tag relationships.
- Timestamps (`createdAt`, `updatedAt`, `lastUsedAt`).

## Storage location
- Data is persisted via SwiftData in the app’s sandboxed container.
- Preference values are stored in `UserDefaults` via `@AppStorage` (see `CONFIGURATION.md`).

## Retention
- There is no automatic retention or purge policy.
- Archived prompts remain in the store until explicitly deleted.

## Backup and restore
- There is no built-in export/import in the current app target.
- Use macOS backup tooling (Time Machine or managed backup solutions) to capture the app container.
