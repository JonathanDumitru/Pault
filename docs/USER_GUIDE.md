# User guide

## Getting started
- Launch Pault to see the sidebar list and the detail editor.
- Use **⌘N** to create a new prompt.

## Create a prompt
- Click the **+** button or use **⌘N**.
- Enter a title and/or content (at least one is required).
- Changes save automatically as you type.

## Edit a prompt
- Select a prompt from the sidebar.
- Edit the title or content directly in the editor.
- Updates are saved after a short debounce.

## Tags
- Open the inspector (info button or **⌘I**).
- Add existing tags or create new ones with a color.
- Click a tag pill in the sidebar list to filter by that tag.

## Favorites and archive
- Toggle favorite from the context menu or inspector.
- Archive prompts to remove them from the default list.
- Use the **Archived** filter to view archived prompts.

## Search and filters
- Use the search field in the sidebar to match title, content, or tag name.
- Filters include **Recently Used**, **All Prompts**, and **Archived**.

## Menu bar access
- Click the menu bar icon to open the mini library.
- Search, expand a prompt, and use **Copy**, **Paste**, **Favorite**, **Archive**, or **Delete**.
- Create a new prompt from the popover.

## Global hotkey launcher
- Press **⌘⇧P** to open the launcher from anywhere.
- Type to search, then press **Return** to perform the default action.
- The default action is configurable in Preferences: **Show Options** (default), **Copy**, or **Paste**.

## Copy and paste feedback
- A floating toast notification confirms when a prompt has been copied to the clipboard.
- Delete actions require confirmation before removing a prompt.

## Preferences
- Open **Settings** from the menu bar popover or the app menu.
- **Launch at login** toggles automatic startup.
- **Show dock icon** switches between accessory and regular app modes.
- **Default action** controls what happens when you select a prompt in the launcher: show options, copy to clipboard, or paste into the frontmost app.
- **Paste delay** controls the delay (in milliseconds) before simulating ⌘V after copying.

## Tips
- Use short titles for faster scanning in the sidebar and launcher.
- Add tags for long-term organization and favorites for quick access.
- Empty state messages guide you when no prompts match your search or filter.

## FAQ
### Why don’t I see archived prompts?
- Archived prompts are hidden from the default list. Switch to **Archived** in the sidebar.

### Why doesn't the hotkey work?
- Ensure Pault is running. If paste actions fail, macOS will automatically prompt for Accessibility permission. Grant access in **System Settings > Privacy & Security > Accessibility**.

### Can I export or import prompts?
- Not yet. Export/import is planned but not implemented in the current app target.
