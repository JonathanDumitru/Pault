#!/usr/bin/env python3
"""
Social Media Marketing Campaign Builder

Generates HTML pages and PDF documents from markdown content files
for social media marketing campaigns.

Usage:
    python build_social_media.py <app_folder>
    python build_social_media.py pault
"""

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


# =============================================================================
# Data Classes
# =============================================================================

@dataclass
class Post:
    """Represents a single social media post."""
    day: int
    platforms: list[str]
    post_type: str
    content: str
    visual: str
    hashtags: str
    title: str = ""


@dataclass
class Week:
    """Represents a week of content."""
    number: int
    theme: str
    description: str
    posts: list[Post] = field(default_factory=list)


@dataclass
class AppConfig:
    """Application configuration from config.json."""
    app_name: str
    tagline: str
    platforms: list[str]
    hashtags: list[str]


# =============================================================================
# Parsing Functions
# =============================================================================

def parse_yaml_frontmatter(text: str) -> tuple[dict, str]:
    """
    Parse YAML frontmatter from text.

    Returns:
        Tuple of (frontmatter dict, remaining content)
    """
    # Match frontmatter between --- markers
    pattern = r'^---\s*\n(.*?)\n---\s*\n?'
    match = re.match(pattern, text, re.DOTALL)

    if not match:
        return {}, text

    frontmatter_text = match.group(1)
    remaining = text[match.end():]

    # Simple YAML parsing (handles our specific format)
    frontmatter = {}
    for line in frontmatter_text.strip().split('\n'):
        if ':' in line:
            key, value = line.split(':', 1)
            key = key.strip()
            value = value.strip()

            # Handle quoted strings
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
            elif value.startswith("'") and value.endswith("'"):
                value = value[1:-1]
            # Handle lists [item1, item2]
            elif value.startswith('[') and value.endswith(']'):
                items = value[1:-1].split(',')
                value = [item.strip().strip('"').strip("'") for item in items]
            # Handle integers
            elif value.isdigit():
                value = int(value)

            frontmatter[key] = value

    return frontmatter, remaining


def parse_post_content(content: str) -> tuple[str, str, str, str]:
    """
    Parse post content to extract title, body, visual description, and hashtags.

    Returns:
        Tuple of (title, body_content, visual_description, hashtags)
    """
    lines = content.strip().split('\n')

    title = ""
    body_lines = []
    visual_lines = []
    hashtag_lines = []

    current_section = "body"

    for line in lines:
        # Check for title (# heading)
        if line.startswith('# ') and not title:
            title = line[2:].strip()
            continue

        # Check for section headers
        if line.strip().lower() == '## visual description':
            current_section = "visual"
            continue
        elif line.strip().lower() == '## hashtags':
            current_section = "hashtags"
            continue
        elif line.startswith('## '):
            # Other h2 headers stay in body
            pass

        # Add line to appropriate section
        if current_section == "body":
            body_lines.append(line)
        elif current_section == "visual":
            visual_lines.append(line)
        elif current_section == "hashtags":
            hashtag_lines.append(line)

    body = '\n'.join(body_lines).strip()
    visual = '\n'.join(visual_lines).strip()
    hashtags = '\n'.join(hashtag_lines).strip()

    return title, body, visual, hashtags


def parse_markdown_file(filepath: Path) -> Optional[Week]:
    """
    Parse a week's markdown file into a Week object with posts.

    Args:
        filepath: Path to the markdown file

    Returns:
        Week object or None if parsing fails
    """
    print(f"  Parsing: {filepath.name}")

    try:
        content = filepath.read_text(encoding='utf-8')
    except Exception as e:
        print(f"    Error reading file: {e}")
        return None

    # Parse week frontmatter
    week_meta, remaining = parse_yaml_frontmatter(content)

    if 'week' not in week_meta:
        print(f"    Warning: No week number found in frontmatter")
        # Try to extract from filename
        match = re.search(r'week-(\d+)', filepath.stem)
        if match:
            week_meta['week'] = int(match.group(1))
        else:
            return None

    week = Week(
        number=week_meta.get('week', 0),
        theme=week_meta.get('theme', ''),
        description=week_meta.get('description', '')
    )

    # Split remaining content by --- separators to get individual posts
    # Filter out empty sections
    post_sections = [s.strip() for s in remaining.split('---') if s.strip()]

    for section in post_sections:
        # Each section should have frontmatter + content
        post_meta, post_content = parse_yaml_frontmatter('---\n' + section + '\n---\n')

        if not post_meta:
            # Try parsing without adding frontmatter markers
            # This handles case where section already has proper format
            if section.strip():
                post_meta, post_content = parse_yaml_frontmatter(section)

        if 'day' not in post_meta:
            # Not a post section, might be leftover content
            continue

        title, body, visual, hashtags = parse_post_content(post_content if post_content else section)

        post = Post(
            day=post_meta.get('day', 0),
            platforms=post_meta.get('platforms', []),
            post_type=post_meta.get('type', 'general'),
            content=body,
            visual=visual,
            hashtags=hashtags,
            title=title
        )

        week.posts.append(post)
        print(f"    Found post: Day {post.day} - {post.title or '(no title)'}")

    print(f"    Total posts: {len(week.posts)}")
    return week


def load_config(config_path: Path) -> Optional[AppConfig]:
    """Load and parse the app configuration file."""
    print(f"Loading config: {config_path}")

    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        return AppConfig(
            app_name=data.get('app_name', 'App'),
            tagline=data.get('tagline', ''),
            platforms=data.get('platforms', []),
            hashtags=data.get('hashtags', [])
        )
    except FileNotFoundError:
        print(f"  Warning: Config file not found, using defaults")
        return AppConfig(
            app_name='App',
            tagline='',
            platforms=['linkedin', 'facebook'],
            hashtags=[]
        )
    except json.JSONDecodeError as e:
        print(f"  Error parsing config: {e}")
        return None


# =============================================================================
# HTML Generation
# =============================================================================

def generate_platform_badges(platforms: list[str]) -> str:
    """Generate HTML for platform badges."""
    platform_colors = {
        'linkedin': '#0077B5',
        'facebook': '#1877F2',
        'twitter': '#1DA1F2',
        'x': '#000000',
        'instagram': '#E4405F',
        'threads': '#000000',
        'mastodon': '#6364FF',
        'bluesky': '#0085FF',
    }

    badges = []
    for platform in platforms:
        color = platform_colors.get(platform.lower(), '#666666')
        badge = f'<span class="platform-badge" style="background-color: {color};">{platform.title()}</span>'
        badges.append(badge)

    return ' '.join(badges)


def generate_post_card(post: Post, template: str) -> str:
    """Generate HTML for a single post card."""
    # Convert content markdown to simple HTML
    content_html = post.content.replace('\n\n', '</p><p>').replace('\n', '<br>')
    if content_html and not content_html.startswith('<p>'):
        content_html = f'<p>{content_html}</p>'

    # Generate platform badges
    platforms_html = generate_platform_badges(post.platforms)

    # Replace template variables
    html = template
    html = html.replace('{{day}}', str(post.day))
    html = html.replace('{{platforms}}', platforms_html)
    html = html.replace('{{type}}', post.post_type)
    html = html.replace('{{content}}', content_html)
    html = html.replace('{{visual}}', post.visual)
    html = html.replace('{{hashtags}}', post.hashtags)
    html = html.replace('{{title}}', post.title)

    return html


def generate_week_page(
    week: Week,
    config: AppConfig,
    template: str,
    post_template: str,
    prev_week: Optional[int],
    next_week: Optional[int]
) -> str:
    """Generate HTML page for a week."""
    # Generate all post cards
    posts_html = []
    for post in sorted(week.posts, key=lambda p: p.day):
        post_html = generate_post_card(post, post_template)
        posts_html.append(post_html)

    posts_combined = '\n'.join(posts_html)

    # Generate navigation links
    prev_link = f'<a href="week-{prev_week:02d}.html">&larr; Week {prev_week}</a>' if prev_week else ''
    next_link = f'<a href="week-{next_week:02d}.html">Week {next_week} &rarr;</a>' if next_week else ''

    # Platform list
    platforms_list = ', '.join(p.title() for p in config.platforms)

    # Replace template variables
    html = template
    html = html.replace('{{app_name}}', config.app_name)
    html = html.replace('{{tagline}}', config.tagline)
    html = html.replace('{{week_number}}', str(week.number))
    html = html.replace('{{week_theme}}', week.theme)
    html = html.replace('{{week_description}}', week.description)
    html = html.replace('{{posts}}', posts_combined)
    html = html.replace('{{prev_link}}', prev_link)
    html = html.replace('{{next_link}}', next_link)
    html = html.replace('{{post_count}}', str(len(week.posts)))
    html = html.replace('{{platforms}}', platforms_list)

    return html


def get_default_templates() -> tuple[str, str, str]:
    """Return default templates if template files don't exist."""

    styles_css = """
/* Social Media Marketing Campaign Styles */

:root {
    --primary-color: #2563eb;
    --secondary-color: #64748b;
    --background: #f8fafc;
    --card-bg: #ffffff;
    --text-primary: #1e293b;
    --text-secondary: #64748b;
    --border-color: #e2e8f0;
}

* {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: var(--background);
    color: var(--text-primary);
    line-height: 1.6;
    padding: 2rem;
}

.container {
    max-width: 900px;
    margin: 0 auto;
}

header {
    text-align: center;
    margin-bottom: 3rem;
    padding-bottom: 2rem;
    border-bottom: 1px solid var(--border-color);
}

header h1 {
    font-size: 2.5rem;
    margin-bottom: 0.5rem;
    color: var(--primary-color);
}

header .tagline {
    font-size: 1.1rem;
    color: var(--text-secondary);
    margin-bottom: 1rem;
}

.week-info {
    background: var(--primary-color);
    color: white;
    padding: 1.5rem;
    border-radius: 12px;
    margin-bottom: 2rem;
}

.week-info h2 {
    font-size: 1.5rem;
    margin-bottom: 0.5rem;
}

.week-info .description {
    opacity: 0.9;
}

.post-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.post-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
    padding-bottom: 0.75rem;
    border-bottom: 1px solid var(--border-color);
}

.post-header .day {
    font-weight: 600;
    font-size: 1.1rem;
}

.post-header .type {
    background: #f1f5f9;
    padding: 0.25rem 0.75rem;
    border-radius: 20px;
    font-size: 0.85rem;
    color: var(--text-secondary);
}

.platform-badge {
    display: inline-block;
    color: white;
    padding: 0.2rem 0.6rem;
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 500;
    margin-right: 0.25rem;
}

.post-content {
    margin: 1rem 0;
}

.post-content p {
    margin-bottom: 0.75rem;
}

.visual-section {
    background: #fef3c7;
    border-left: 4px solid #f59e0b;
    padding: 1rem;
    margin: 1rem 0;
    border-radius: 0 8px 8px 0;
}

.visual-section h4 {
    font-size: 0.85rem;
    color: #92400e;
    margin-bottom: 0.5rem;
}

.hashtags {
    color: var(--primary-color);
    font-size: 0.9rem;
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid var(--border-color);
}

.navigation {
    display: flex;
    justify-content: space-between;
    margin-top: 3rem;
    padding-top: 2rem;
    border-top: 1px solid var(--border-color);
}

.navigation a {
    color: var(--primary-color);
    text-decoration: none;
    font-weight: 500;
}

.navigation a:hover {
    text-decoration: underline;
}

footer {
    text-align: center;
    margin-top: 3rem;
    padding-top: 2rem;
    border-top: 1px solid var(--border-color);
    color: var(--text-secondary);
    font-size: 0.9rem;
}

/* PDF-specific styles */
@media print {
    body {
        padding: 0;
    }

    .post-card {
        break-inside: avoid;
    }

    .navigation {
        display: none;
    }
}
"""

    post_template = """
<article class="post-card">
    <div class="post-header">
        <span class="day">Day {{day}}</span>
        <span class="type">{{type}}</span>
    </div>
    <div class="platforms">{{platforms}}</div>
    <div class="post-content">
        {{content}}
    </div>
    <div class="visual-section">
        <h4>Visual Description</h4>
        <p>{{visual}}</p>
    </div>
    <div class="hashtags">{{hashtags}}</div>
</article>
"""

    week_template = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{app_name}} - Week {{week_number}}: {{week_theme}}</title>
    <style>
""" + styles_css + """
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>{{app_name}}</h1>
            <p class="tagline">{{tagline}}</p>
        </header>

        <div class="week-info">
            <h2>Week {{week_number}}: {{week_theme}}</h2>
            <p class="description">{{week_description}}</p>
            <p class="meta">{{post_count}} posts | Platforms: {{platforms}}</p>
        </div>

        <main>
            {{posts}}
        </main>

        <nav class="navigation">
            <div>{{prev_link}}</div>
            <div>{{next_link}}</div>
        </nav>

        <footer>
            <p>Social Media Marketing Campaign for {{app_name}}</p>
        </footer>
    </div>
</body>
</html>
"""

    return week_template, post_template, styles_css


def load_templates(templates_dir: Path) -> tuple[str, str, str]:
    """Load templates from files or use defaults."""
    week_template, post_template, styles_css = get_default_templates()

    week_path = templates_dir / 'week-page.html'
    post_path = templates_dir / 'post-card.html'
    styles_path = templates_dir / 'styles.css'

    if week_path.exists():
        print(f"  Loading: {week_path.name}")
        week_template = week_path.read_text(encoding='utf-8')
    else:
        print(f"  Using default week template")

    if post_path.exists():
        print(f"  Loading: {post_path.name}")
        post_template = post_path.read_text(encoding='utf-8')
    else:
        print(f"  Using default post template")

    if styles_path.exists():
        print(f"  Loading: {styles_path.name}")
        styles_css = styles_path.read_text(encoding='utf-8')
    else:
        print(f"  Using default styles")

    return week_template, post_template, styles_css


# =============================================================================
# PDF Generation
# =============================================================================

def generate_pdf(html_files: list[Path], output_path: Path, config: AppConfig) -> bool:
    """
    Generate a master PDF from all HTML files.

    Returns:
        True if successful, False otherwise
    """
    print(f"\nGenerating PDF: {output_path.name}")

    # Try to use weasyprint
    try:
        from weasyprint import HTML, CSS

        # Combine all HTML into one document
        combined_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>{config.app_name} - Social Media Marketing Campaign</title>
</head>
<body>
"""

        for html_file in sorted(html_files):
            content = html_file.read_text(encoding='utf-8')
            # Extract body content
            body_match = re.search(r'<body[^>]*>(.*?)</body>', content, re.DOTALL)
            if body_match:
                combined_html += f'\n<div class="week-section">\n{body_match.group(1)}\n</div>\n'
                combined_html += '<div style="page-break-after: always;"></div>\n'

        combined_html += """
</body>
</html>
"""

        # Get styles from first HTML file
        if html_files:
            first_content = html_files[0].read_text(encoding='utf-8')
            style_match = re.search(r'<style>(.*?)</style>', first_content, re.DOTALL)
            if style_match:
                css = CSS(string=style_match.group(1))
                HTML(string=combined_html).write_pdf(output_path, stylesheets=[css])
            else:
                HTML(string=combined_html).write_pdf(output_path)

        print(f"  PDF generated successfully with WeasyPrint")
        return True

    except ImportError:
        print(f"  WeasyPrint not available, creating HTML-only output")
        print(f"  Install with: pip install weasyprint")

        # Create a combined HTML file as fallback
        fallback_path = output_path.with_suffix('.html')

        combined_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>{config.app_name} - Social Media Marketing Campaign</title>
    <style>
        .page-break {{ page-break-after: always; }}
    </style>
</head>
<body>
    <h1 style="text-align: center;">{config.app_name} - Social Media Marketing Campaign</h1>
    <p style="text-align: center;">Print this page to PDF for a complete document</p>
    <hr>
"""

        for html_file in sorted(html_files):
            content = html_file.read_text(encoding='utf-8')
            body_match = re.search(r'<body[^>]*>(.*?)</body>', content, re.DOTALL)
            if body_match:
                combined_html += f'\n<div class="page-break">\n{body_match.group(1)}\n</div>\n'

        combined_html += """
</body>
</html>
"""

        fallback_path.write_text(combined_html, encoding='utf-8')
        print(f"  Created fallback HTML: {fallback_path.name}")
        return False

    except Exception as e:
        print(f"  Error generating PDF: {e}")
        return False


# =============================================================================
# Main Build Process
# =============================================================================

def build_campaign(app_folder: str, base_dir: Path) -> bool:
    """
    Build the social media marketing campaign.

    Args:
        app_folder: Name of the app folder (e.g., 'pault')
        base_dir: Base directory containing app folders

    Returns:
        True if successful, False otherwise
    """
    print(f"\n{'=' * 60}")
    print(f"Building Social Media Campaign: {app_folder}")
    print(f"{'=' * 60}\n")

    # Set up paths
    app_dir = base_dir / app_folder
    content_dir = app_dir / 'content'
    output_html_dir = app_dir / 'output' / 'html'
    output_pdf_dir = app_dir / 'output' / 'pdf'
    config_path = app_dir / 'config.json'
    templates_dir = base_dir / 'templates'

    # Verify directories exist
    if not app_dir.exists():
        print(f"Error: App directory not found: {app_dir}")
        return False

    if not content_dir.exists():
        print(f"Error: Content directory not found: {content_dir}")
        return False

    # Create output directories
    output_html_dir.mkdir(parents=True, exist_ok=True)
    output_pdf_dir.mkdir(parents=True, exist_ok=True)
    print(f"Output directories ready")

    # Load configuration
    config = load_config(config_path)
    if config is None:
        return False
    print(f"  App: {config.app_name}")
    print(f"  Tagline: {config.tagline}")
    print(f"  Platforms: {', '.join(config.platforms)}")

    # Load templates
    print(f"\nLoading templates...")
    week_template, post_template, styles_css = load_templates(templates_dir)

    # Parse all markdown files
    print(f"\nParsing content files...")
    markdown_files = sorted(content_dir.glob('week-*.md'))

    if not markdown_files:
        print(f"  No markdown files found matching 'week-*.md'")
        return False

    weeks: list[Week] = []
    for md_file in markdown_files:
        week = parse_markdown_file(md_file)
        if week:
            weeks.append(week)

    if not weeks:
        print(f"\nError: No valid weeks parsed")
        return False

    # Sort weeks by number
    weeks.sort(key=lambda w: w.number)
    week_numbers = [w.number for w in weeks]

    print(f"\nParsed {len(weeks)} weeks with {sum(len(w.posts) for w in weeks)} total posts")

    # Generate HTML files
    print(f"\nGenerating HTML files...")
    html_files: list[Path] = []

    for i, week in enumerate(weeks):
        # Determine prev/next week numbers
        prev_week = week_numbers[i - 1] if i > 0 else None
        next_week = week_numbers[i + 1] if i < len(weeks) - 1 else None

        # Generate HTML
        html_content = generate_week_page(
            week=week,
            config=config,
            template=week_template,
            post_template=post_template,
            prev_week=prev_week,
            next_week=next_week
        )

        # Write file
        output_file = output_html_dir / f'week-{week.number:02d}.html'
        output_file.write_text(html_content, encoding='utf-8')
        html_files.append(output_file)
        print(f"  Created: {output_file.name}")

    # Generate index page
    print(f"\nGenerating index page...")
    index_html = generate_index_page(weeks, config)
    index_file = output_html_dir / 'index.html'
    index_file.write_text(index_html, encoding='utf-8')
    print(f"  Created: {index_file.name}")

    # Generate PDF
    pdf_file = output_pdf_dir / f'{app_folder}-social-media-campaign.pdf'
    generate_pdf(html_files, pdf_file, config)

    # Summary
    print(f"\n{'=' * 60}")
    print(f"Build Complete!")
    print(f"{'=' * 60}")
    print(f"\nGenerated files:")
    print(f"  HTML: {output_html_dir}")
    print(f"  PDF:  {output_pdf_dir}")
    print(f"\nTotal: {len(html_files)} week pages + 1 index page")

    return True


def generate_index_page(weeks: list[Week], config: AppConfig) -> str:
    """Generate an index page linking to all weeks."""

    week_links = []
    for week in weeks:
        post_count = len(week.posts)
        week_links.append(f'''
        <a href="week-{week.number:02d}.html" class="week-link">
            <div class="week-number">Week {week.number}</div>
            <div class="week-theme">{week.theme}</div>
            <div class="week-meta">{post_count} posts</div>
        </a>
        ''')

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{config.app_name} - Social Media Campaign</title>
    <style>
        :root {{
            --primary-color: #2563eb;
            --background: #f8fafc;
            --card-bg: #ffffff;
            --text-primary: #1e293b;
            --text-secondary: #64748b;
            --border-color: #e2e8f0;
        }}

        * {{ box-sizing: border-box; margin: 0; padding: 0; }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: var(--background);
            color: var(--text-primary);
            line-height: 1.6;
            padding: 2rem;
        }}

        .container {{
            max-width: 800px;
            margin: 0 auto;
        }}

        header {{
            text-align: center;
            margin-bottom: 3rem;
        }}

        header h1 {{
            font-size: 2.5rem;
            color: var(--primary-color);
            margin-bottom: 0.5rem;
        }}

        header .tagline {{
            color: var(--text-secondary);
            font-size: 1.1rem;
        }}

        .stats {{
            display: flex;
            justify-content: center;
            gap: 2rem;
            margin: 2rem 0;
        }}

        .stat {{
            text-align: center;
        }}

        .stat-value {{
            font-size: 2rem;
            font-weight: bold;
            color: var(--primary-color);
        }}

        .stat-label {{
            color: var(--text-secondary);
            font-size: 0.9rem;
        }}

        .weeks-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
            gap: 1rem;
            margin-top: 2rem;
        }}

        .week-link {{
            display: block;
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 1.5rem;
            text-decoration: none;
            color: inherit;
            transition: transform 0.2s, box-shadow 0.2s;
        }}

        .week-link:hover {{
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
        }}

        .week-number {{
            font-weight: 600;
            color: var(--primary-color);
            margin-bottom: 0.25rem;
        }}

        .week-theme {{
            font-size: 1.1rem;
            margin-bottom: 0.5rem;
        }}

        .week-meta {{
            font-size: 0.85rem;
            color: var(--text-secondary);
        }}

        footer {{
            text-align: center;
            margin-top: 3rem;
            padding-top: 2rem;
            border-top: 1px solid var(--border-color);
            color: var(--text-secondary);
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>{config.app_name}</h1>
            <p class="tagline">{config.tagline}</p>
        </header>

        <div class="stats">
            <div class="stat">
                <div class="stat-value">{len(weeks)}</div>
                <div class="stat-label">Weeks</div>
            </div>
            <div class="stat">
                <div class="stat-value">{sum(len(w.posts) for w in weeks)}</div>
                <div class="stat-label">Posts</div>
            </div>
            <div class="stat">
                <div class="stat-value">{len(config.platforms)}</div>
                <div class="stat-label">Platforms</div>
            </div>
        </div>

        <h2>Campaign Content</h2>

        <div class="weeks-grid">
            {''.join(week_links)}
        </div>

        <footer>
            <p>Social Media Marketing Campaign for {config.app_name}</p>
            <p>Platforms: {', '.join(p.title() for p in config.platforms)}</p>
        </footer>
    </div>
</body>
</html>
"""


# =============================================================================
# CLI Entry Point
# =============================================================================

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Build social media marketing campaign from markdown files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python build_social_media.py pault
    python build_social_media.py schemap

Directory structure expected:
    social-media-marketing/
    ├── pault/
    │   ├── content/
    │   │   ├── week-01.md
    │   │   └── week-02.md
    │   ├── output/
    │   │   ├── html/
    │   │   └── pdf/
    │   └── config.json
    ├── templates/
    │   ├── post-card.html
    │   ├── week-page.html
    │   └── styles.css
    └── scripts/
        └── build_social_media.py
        """
    )

    parser.add_argument(
        'app',
        help='App folder name (e.g., pault)'
    )

    parser.add_argument(
        '--base-dir',
        type=Path,
        default=None,
        help='Base directory (defaults to parent of scripts folder)'
    )

    args = parser.parse_args()

    # Determine base directory
    if args.base_dir:
        base_dir = args.base_dir
    else:
        # Default: parent directory of scripts folder
        base_dir = Path(__file__).parent.parent

    base_dir = base_dir.resolve()

    # Run build
    success = build_campaign(args.app, base_dir)

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
