# Troubleshooting

## Global hotkey does not open the launcher
- Confirm Pault is running.
- Open `Settings > Hotkey` and verify the recorded shortcut.
- Check for conflicts with other apps using the same shortcut.
- If it still fails, look in Console for hotkey registration warnings from the Pault process.

## AI features fail or show connection errors
- Open `Settings > AI` and verify the provider API key or Ollama base URL.
- Use `Test Connection` for the affected provider.
- Confirm your network can reach the selected provider endpoint.
- If Ollama is selected, confirm the local server is running at the configured base URL.

## Prompt content copied from export/import looks incomplete
- The current exporter preserves plain text, tags, and template-variable values only.
- Rich text, attachments, versions, runs, smart collections, templates, custom blocks, and block compositions are not restored from export.

## Prompts appear missing
- Check the `Archived` filter.
- Clear the search field.
- If a smart collection is selected, switch back to `All Prompts`.

## Changes are not saved between launches
- If SwiftData fails to open the persistent store, Pault falls back to an in-memory container.
- Look for messages like `SwiftData persistent store failed` in Console.
- If you hit this state, back up the container and attachment directories before reinstalling or resetting data.

## Attachments do not reopen
- Referenced attachments depend on valid security-scoped bookmarks and an accessible original file location.
- If the original referenced file was moved or deleted outside Pault, reopen or reattach it from its new location.

## Block editor changes disappeared
- In block mode, use `Save` to persist the canvas back into the prompt.
- If you switch prompts while the canvas is dirty, Pault shows an unsaved-changes dialog. Confirm you did not discard changes there.

## Copied text still contains `{{variable}}`
- One or more template variables are still empty.
- Fill the variable values in the main editor before copying if you want fully resolved output.
