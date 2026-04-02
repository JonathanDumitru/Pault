# Data handling

## Stored data
Pault stores:
- Prompt titles, prompt content, optional rich-text content, favorite/archive flags, and timestamps.
- Template variables and tags.
- Attachment metadata and, for embedded files, attachment copies on disk.
- Prompt versions, prompt runs, and copy-event analytics records.
- Prompt templates, smart collections, custom blocks, and block-editor composition metadata.

## Storage locations
- SwiftData records are persisted in the app’s sandboxed container.
- Preference values are stored in `UserDefaults`.
- API keys are stored in Keychain.
- Embedded attachment files are stored in Application Support; large referenced files remain in their original location and are reopened via bookmark data.

## Retention
- There is no automatic retention or purge policy.
- Archived prompts remain in the store until explicitly deleted.
- Version history, runs, and analytics records also persist until deleted or the data store is reset.

## Backup and restore
- The app includes built-in JSON export/import for prompt-library backup.
- The exporter does not preserve every stored model. It is not a full-fidelity restore path for attachments, versions, runs, templates, smart collections, custom blocks, or block compositions.
- For full recovery, use standard backup tooling on the app container and attachment storage directories.
