# Social Media Marketing Campaign Design

## Overview

A 90-day social media marketing campaign for Pault (and reusable for other apps) targeting Facebook and LinkedIn. Primary goal: **attract job opportunities** by showcasing software architecture and product-building skills.

**Positioning:** Product-minded technical generalist who can solo own the full stack.

## Approach: Weekly Themed Bundles

13-week narrative arc with 10 posts per week (130 total posts). Content organized by weekly themes that tell a coherent story of building a product.

## Folder Structure

```
social-media-marketing/
├── pault/
│   ├── content/                    # SOURCE (Markdown)
│   │   ├── week-01.md
│   │   ├── week-02.md
│   │   └── ... (13 weeks)
│   ├── output/                     # GENERATED
│   │   ├── html/
│   │   │   └── week-01.html (etc.)
│   │   └── pdf/
│   │       └── pault-90-day-campaign.pdf
│   └── config.json                 # App metadata
├── templates/
│   ├── post-card.html              # Single post template
│   ├── week-page.html              # Weekly page template
│   └── styles.css                  # Shared styling
└── scripts/
    └── build_social_media.py       # Markdown → HTML/PDF
```

## Weekly Theme Arc (13 Weeks)

| Week | Theme | Focus |
|------|-------|-------|
| 1 | **Why I Built This** | Origin story, problem you were solving |
| 2 | **The Problem Space** | User pain points, market gap |
| 3 | **Early Design Decisions** | Architecture choices, why SwiftUI/SwiftData |
| 4 | **Building the Core** | Key features, technical deep dives |
| 5 | **Multi-Surface Design** | Menu bar + hotkey + main window system |
| 6 | **The Template Engine** | Variable system, dynamic prompts |
| 7 | **AI-Assisted Development** | How you use Claude Code to build |
| 8 | **Challenges & Pivots** | What went wrong, how you adapted |
| 9 | **Privacy-First Architecture** | Local-only design decisions |
| 10 | **Polish & UX Details** | Small touches that matter |
| 11 | **Building Block Editor** | New visual composition feature |
| 12 | **From Side Project to Product** | Lessons on shipping |
| 13 | **What's Next** | Roadmap, your growth as a builder |

## Content Mix per Week (10 posts)

| Posts | Type | Description |
|-------|------|-------------|
| 3 | **Technical** | Architecture decisions, code patterns, problem-solving |
| 3 | **Product** | Features, demos, user benefits |
| 2 | **Personal/Journey** | Lessons learned, your story, reflections |
| 2 | **Behind-the-scenes** | Process, tools, AI-assisted development |

## Post Structure

Each post includes:
- **Date** (Day within week)
- **Platform badges** (LinkedIn / Facebook / Both)
- **Post text** with copy button
- **Visual description** for AI image generation
- **Hashtags** with copy button
- **Content type tag** (Technical / Personal / Product / Behind-the-scenes)

## HTML Output Format

```
┌─────────────────────────────────────────┐
│ Day 3 · Week 1         [LinkedIn] [FB]  │
├─────────────────────────────────────────┤
│ POST TEXT                    [📋 Copy]  │
│ ────────────────────────────────────    │
│ I spent two weeks refining a single     │
│ keyboard shortcut. Here's why that...   │
├─────────────────────────────────────────┤
│ 🖼 VISUAL DESCRIPTION                   │
│ Screenshot showing the global hotkey    │
│ launcher appearing over a code editor   │
├─────────────────────────────────────────┤
│ #BuildInPublic #macOS...    [📋 Copy]   │
└─────────────────────────────────────────┘
```

## Build Pipeline

Source format: Markdown files per week
Output: HTML with copy buttons + master PDF

Build script (`scripts/build_social_media.py`):
- Reads markdown content from `content/` folder
- Parses post structure (YAML frontmatter + content)
- Injects copy-button JavaScript
- Generates styled HTML per week
- Compiles master PDF for offline reference
- Configurable per app via `config.json`

## Reusability

Each new app campaign:
1. Copy folder structure
2. Update `config.json` with app metadata
3. Adapt weekly content (same themes, different examples)
4. Run build script

## Visual Asset Approach

- Posts include visual descriptions (not AI prompts)
- User generates images using AI tools based on descriptions
- Descriptions focus on what the image should show
