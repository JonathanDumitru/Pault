# Configuration

Pault stores preferences primarily through `@AppStorage` in `UserDefaults`.

## Core preference keys

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `globalHotkey` | String | `⌘⇧P` | Display string for the current hotkey. |
| `hotkeyKeyCode` | Int | `P` keycode | Actual registered key code. |
| `hotkeyModifiers` | Int | `cmd + shift` | Actual registered modifier flags. |
| `launchAtLogin` | Bool | `false` | Controls `SMAppService` registration. |
| `showDockIcon` | Bool | `false` | Toggles activation policy. |
| `defaultAction` | String | `showOptions` | Launcher behavior: `showOptions` or `copy`. |
| `versionHistoryLimit` | Int | `50` | Maximum retained versions per prompt. |
| `fontSizePreference` | String | `medium` | Appearance setting. |
| `useCompactMode` | Bool | `false` | Appearance and list-density setting. |
| `accentColorPreference` | String | `blue` | Accent-color selection. |

## AI-related settings

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `ai.model.claude` | String | `claude-opus-4-6` | Claude model name. |
| `ai.model.openai` | String | `gpt-4o` | OpenAI model name. |
| `ai.model.ollama` | String | `llama3` | Ollama model name. |
| `ai.baseURL.ollama` | String | `http://localhost:11434` | Local Ollama endpoint. |

API keys are stored in Keychain, not `UserDefaults`, using these logical accounts:
- `ai.apikey.claude`
- `ai.apikey.openai`

## UI and onboarding flags
- `hasCompletedOnboarding`
- `showSidebar`
- `showInspector`
- `showBlockLibrary`
- `showBlockPreview`
- `hasSeenBlockEditorOnboarding`
- `hasDiscoveredAIAssist`
- `coachingDismissedVariables`
- `coachingDismissedTags`

## Managed settings
- No dedicated managed-configuration profile support is implemented.
- MDM tooling can pre-seed `UserDefaults` values in the app domain.
- AI API keys still need a Keychain provisioning strategy if they are to be installed centrally.
