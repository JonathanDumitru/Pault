# Configuration

Pault stores preferences via `@AppStorage` in `UserDefaults`.

## Preference keys

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `globalHotkey` | String | `⌘⇧P` | Display-only; hotkey is not configurable yet. |
| `launchAtLogin` | Bool | `false` | Controls `SMAppService` registration. |
| `showDockIcon` | Bool | `false` | Toggles activation policy (accessory vs regular). |
| `defaultAction` | String | `showOptions` | Launcher behavior on select: `showOptions`, `copy`, or `paste`. |
| `pasteDelay` | Double | `100` | Delay in milliseconds before simulating ⌘V paste. |

## Managed settings
- No managed configuration profile support is implemented yet.
- If you need to pre-seed defaults, use your MDM tooling to write the above keys into the app’s preferences domain.
