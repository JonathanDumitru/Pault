# Data store and backup

## SwiftData location
Pault stores its SwiftData-backed records in the sandboxed container for bundle id `Jonathan-Hines-Dumitru.Pault`.

Typical container root:

```text
~/Library/Containers/Jonathan-Hines-Dumitru.Pault/
```

SwiftData store files are typically found under:

```text
~/Library/Containers/Jonathan-Hines-Dumitru.Pault/Data/Library/Application Support/
```

## Attachment storage
- Embedded attachments are copied into Application Support under a Pault-managed attachments directory.
- Referenced attachments store security-scoped bookmark data in SwiftData and continue to point to the original source file.
- Embedded files are currently used for files up to 10 MB. Larger files are referenced instead of copied.

## What is stored
- Prompt records, tags, variables, versions, runs, copy events, templates, smart collections, custom blocks, and prompt metadata live in the SwiftData store.
- Prompt attachments may live partly on disk outside the SQLite store when they are embedded files.
- AI credentials are not stored in SwiftData; they are stored in Keychain.

## Backup
- Use standard macOS backup tooling to capture the app container.
- If you want complete prompt-plus-attachment recovery, back up both the container and the Pault attachments directory in Application Support.
- JSON export from the app is useful for prompt-library backup, but it is not a full-fidelity backup of every stored model.

## Wipe / reset
- Quit the app.
- Delete the app container directory to remove SwiftData records and preferences.
- Delete the Pault attachments directory in Application Support if you also want to remove embedded attachment files.
