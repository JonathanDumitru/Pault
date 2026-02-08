# DMG Styling and Build

Use this script to build a styled DMG window with:
- Custom background art.
- App icon + Applications alias placement.
- Finder icon-view layout presets.

## Command

```bash
scripts/create_dmg.sh build/Release/Pault.app dist/Pault.dmg "Pault"
```

## Inputs

- App bundle: path to `Pault.app`.
- Output DMG path.
- Optional volume name (defaults to `Pault`).

## Assets

- DMG background image: `scripts/dmg/dmg-background.png`

