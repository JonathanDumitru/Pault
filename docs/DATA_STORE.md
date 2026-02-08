# Data store and backup

## Location
Pault stores data in its sandboxed container for bundle id `Jonathan-Hines-Dumitru.Pault`.

Typical location:

```
~/Library/Containers/Jonathan-Hines-Dumitru.Pault/Data/Library/Application Support/
```

SwiftData uses SQLite under the hood. File names can vary; you can locate the store by searching for `*.sqlite` within the container directory.

## Backup
- Use standard macOS backup tooling (Time Machine or enterprise backup agents).
- Back up the entire container directory to preserve prompts and tags.

## Wipe / reset
- Quit the app.
- Delete the container directory to remove all stored prompts and preferences.
