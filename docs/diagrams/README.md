# Diagrams

This directory contains Mermaid source files and PNG exports.

## Sources
- `system-overview.mmd`: Core app surfaces and data flow.
- `prompt-lifecycle.mmd`: Prompt creation, save, and usage flow.
- `feature-surfaces.mmd`: Surface capabilities overview.
- `permissions-flow.mmd`: Permission prompts for paste actions.
- `prompt-state.mmd`: Prompt state transitions.
- `search-filter-flow.mmd`: Search and filter flow by surface.
- `edit-save-flow.mmd`: Debounced save sequence.
- `app-launch-sequence.mmd`: App launch and hotkey setup sequence.
- `tag-relationship.mmd`: Prompt/tag relationship.
- `store-fallback.mmd`: Persistent store fallback path.

## Exports
- `exports/system-overview.png`
- `exports/prompt-lifecycle.png`
- `exports/feature-surfaces.png`
- `exports/permissions-flow.png`
- `exports/prompt-state.png`
- `exports/search-filter-flow.png`
- `exports/edit-save-flow.png`
- `exports/app-launch-sequence.png`
- `exports/tag-relationship.png`
- `exports/store-fallback.png`

## Rendering
PNG exports are generated from Mermaid sources. If you have `@mermaid-js/mermaid-cli` installed, you can render all diagrams with:

```bash
python3 scripts/render_mermaid.py
```

If your environment requires a Puppeteer config, set:

```bash
export MERMAID_PUPPETEER_CONFIG=/path/to/puppeteer-config.json
```

If you prefer direct CLI calls:

```bash
mmdc -i docs/diagrams/system-overview.mmd -o docs/diagrams/exports/system-overview.png
mmdc -i docs/diagrams/prompt-lifecycle.mmd -o docs/diagrams/exports/prompt-lifecycle.png
```
