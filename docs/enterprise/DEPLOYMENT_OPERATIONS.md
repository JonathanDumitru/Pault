# Deployment and operations

## System requirements
- macOS 15.0+.

## Packaging and distribution
- The repository builds as a standard macOS app in Xcode.
- Package and distribute using your existing enterprise tooling (PKG, MDM, or managed app catalogs).

## Updates
- There is no in-app update mechanism in the current app target.
- Distribute updates through your standard software delivery workflow.

## Runtime behavior
- The app can run as a menu bar accessory (dock icon hidden) or regular app (dock icon visible).
- A login item can be enabled via **Launch at login** in preferences.

## Operational notes
- Global hotkey: ⌘⇧P is registered at launch and is not currently configurable.
- If hotkey registration fails, the app writes an error through Apple unified logging.
