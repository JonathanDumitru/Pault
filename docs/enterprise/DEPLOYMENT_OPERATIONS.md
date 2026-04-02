# Deployment and operations

## System requirements
- macOS 15.0+.

## Packaging and distribution
- The repository builds as a standard macOS app in Xcode.
- Package and distribute using your existing PKG, MDM, or managed app catalog workflow.

## Updates
- There is no in-app auto-update mechanism in the current app target.
- Distribute updates through your standard software delivery workflow.

## Runtime behavior
- The app can run as an accessory-style menu bar app or as a regular dock-visible app.
- A login item can be enabled from settings.
- The global hotkey is configurable and registered at launch from stored key-code preferences.

## Operational notes
- First launch seeds built-in prompt templates.
- AI features require outbound access to the selected provider endpoint plus valid credentials in Keychain.
- Export/import is available from the Data settings tab for prompt-library backup and restore.
- Embedded attachments consume local Application Support storage; referenced attachments depend on the original file still being available.
