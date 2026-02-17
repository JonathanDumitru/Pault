#!/usr/bin/env python3
"""
Generate a stylized "Clean Technical" PDF version of the user documentation.

Usage:
  .venv/bin/python scripts/pdf/build_user_guide_pdf.py
  .venv/bin/python scripts/pdf/build_user_guide_pdf.py --output output/pdf/custom-name.pdf
"""

from __future__ import annotations

import argparse
import html
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable

from reportlab.lib import colors
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.lib.utils import ImageReader
from reportlab.platypus import (
    Flowable,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[2]
DOCS_DIR = ROOT / "docs"
DEFAULT_OUTPUT = ROOT / "output" / "pdf" / "pault-user-guide-clean-technical.pdf"

PAGE_WIDTH, PAGE_HEIGHT = LETTER
MARGIN_X = 0.85 * inch
MARGIN_TOP = 0.95 * inch
MARGIN_BOTTOM = 0.75 * inch

COLOR_NAVY = colors.HexColor("#102A43")
COLOR_TEAL = colors.HexColor("#1F7A8C")
COLOR_TEXT = colors.HexColor("#1F2933")
COLOR_MUTED = colors.HexColor("#52606D")
COLOR_LINE = colors.HexColor("#D9E2EC")
COLOR_SURFACE = colors.HexColor("#F7FAFC")


@dataclass(frozen=True)
class CalloutSpec:
    number: int
    anchor_x: float  # normalized x in screenshot area
    anchor_y: float  # normalized y in screenshot area
    title: str
    description: str


@dataclass(frozen=True)
class ScreenshotSpec:
    title: str
    subtitle: str
    candidate_filenames: tuple[str, ...]
    callouts: tuple[CalloutSpec, ...]


SCREENSHOT_SPECS: tuple[ScreenshotSpec, ...] = (
    ScreenshotSpec(
        title="Main Window Workflow",
        subtitle="Library management and editing in the primary split-view workspace.",
        candidate_filenames=(
            "01-library-overview.png",
            "02-editor-detail.png",
            "main-window.png",
            "library-overview.png",
        ),
        callouts=(
            CalloutSpec(1, 0.10, 0.77, "Sidebar filters", "Switch between Recent, All Prompts, and Archived."),
            CalloutSpec(2, 0.25, 0.56, "Prompt list", "Browse prompts and open context actions."),
            CalloutSpec(3, 0.64, 0.80, "Title + editor", "Edit prompt title/content with autosave."),
            CalloutSpec(4, 0.88, 0.18, "Inspector", "Manage tags, favorite state, and archive status."),
        ),
    ),
    ScreenshotSpec(
        title="Menu Bar Quick Access",
        subtitle="Fast search and action controls from the popover surface.",
        candidate_filenames=(
            "03-menu-bar-popover.png",
            "menu-bar-popover.png",
            "menu-bar.png",
        ),
        callouts=(
            CalloutSpec(1, 0.49, 0.85, "Search", "Filter prompts by title, content, or tags."),
            CalloutSpec(2, 0.20, 0.72, "Filter tabs", "Jump to Favorites, All, or Archived."),
            CalloutSpec(3, 0.55, 0.46, "Expanded row", "Copy, paste, favorite, archive, or delete."),
            CalloutSpec(4, 0.84, 0.10, "Bottom bar", "Create prompts, open main window, or open settings."),
        ),
    ),
    ScreenshotSpec(
        title="Hotkey Launcher",
        subtitle="Keyboard-first selection and instant copy/paste actions from any app.",
        candidate_filenames=(
            "04-global-launcher.png",
            "05-quick-paste.png",
            "global-launcher.png",
            "hotkey-launcher.png",
        ),
        callouts=(
            CalloutSpec(1, 0.52, 0.84, "Search input", "Start typing immediately after opening Cmd+Shift+P."),
            CalloutSpec(2, 0.20, 0.56, "Ranked results", "Use Up/Down or Cmd+1..9 shortcuts."),
            CalloutSpec(3, 0.54, 0.24, "Action view", "Choose Copy or Paste when default is Show options."),
            CalloutSpec(4, 0.84, 0.56, "Favorite hints", "Starred prompts stay prominent in launcher results."),
        ),
    ),
)


class AnnotatedScreenshot(Flowable):
    """Image panel with numbered callout markers."""

    def __init__(
        self,
        image_path: Path | None,
        callouts: tuple[CalloutSpec, ...],
        width: float,
        height: float,
    ) -> None:
        super().__init__()
        self.image_path = image_path
        self.callouts = callouts
        self.width = width
        self.height = height

    def wrap(self, availWidth, availHeight):
        return self.width, self.height

    def draw(self) -> None:
        c = self.canv
        x0, y0 = 0, 0

        # Outer panel
        c.setFillColor(colors.white)
        c.setStrokeColor(COLOR_LINE)
        c.setLineWidth(0.8)
        c.roundRect(x0, y0, self.width, self.height, 7, stroke=1, fill=1)

        padding = 6
        pane_x = x0 + padding
        pane_y = y0 + padding
        pane_w = self.width - (2 * padding)
        pane_h = self.height - (2 * padding)

        image_x = pane_x
        image_y = pane_y
        image_w = pane_w
        image_h = pane_h

        if self.image_path is not None and self.image_path.exists():
            reader = ImageReader(str(self.image_path))
            raw_w, raw_h = reader.getSize()
            scale = min(pane_w / raw_w, pane_h / raw_h)
            draw_w = raw_w * scale
            draw_h = raw_h * scale
            image_x = pane_x + (pane_w - draw_w) / 2
            image_y = pane_y + (pane_h - draw_h) / 2
            image_w = draw_w
            image_h = draw_h
            c.drawImage(
                reader,
                image_x,
                image_y,
                width=image_w,
                height=image_h,
                preserveAspectRatio=True,
                mask="auto",
            )
        else:
            c.setFillColor(COLOR_SURFACE)
            c.rect(pane_x, pane_y, pane_w, pane_h, stroke=0, fill=1)
            c.setStrokeColor(COLOR_LINE)
            c.rect(pane_x, pane_y, pane_w, pane_h, stroke=1, fill=0)
            c.setFillColor(COLOR_MUTED)
            c.setFont("Helvetica", 10)
            c.drawCentredString(
                pane_x + pane_w / 2,
                pane_y + pane_h / 2,
                "Screenshot not found. Add PNG in docs/app-store/screenshots/",
            )

        # Callout markers
        for callout in self.callouts:
            cx = image_x + (callout.anchor_x * image_w)
            cy = image_y + (callout.anchor_y * image_h)
            radius = 9
            c.setFillColor(COLOR_TEAL)
            c.circle(cx, cy, radius, stroke=0, fill=1)
            c.setFillColor(colors.white)
            c.setFont("Helvetica-Bold", 8)
            c.drawCentredString(cx, cy - 2.8, str(callout.number))


def format_inline_markdown(text: str) -> str:
    """Convert a small markdown subset to ReportLab paragraph markup."""
    text = (
        text.replace("⌘", "Cmd+")
        .replace("⇧", "Shift+")
        .replace("⌥", "Option+")
        .replace("⌃", "Ctrl+")
        .replace("↑", "Up")
        .replace("↓", "Down")
    )
    escaped = html.escape(text)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(r"`([^`]+)`", r"<font name='Courier'>\1</font>", escaped)
    return escaped


def build_styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()

    styles = {
        "cover_tag": ParagraphStyle(
            "cover_tag",
            parent=base["Normal"],
            fontName="Helvetica-Bold",
            fontSize=10,
            leading=12,
            textColor=COLOR_TEAL,
            spaceAfter=10,
            uppercase=True,
        ),
        "cover_title": ParagraphStyle(
            "cover_title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=34,
            leading=38,
            textColor=COLOR_NAVY,
            spaceAfter=8,
        ),
        "cover_subtitle": ParagraphStyle(
            "cover_subtitle",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=13,
            leading=18,
            textColor=COLOR_MUTED,
            spaceAfter=14,
        ),
        "h1": ParagraphStyle(
            "h1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=21,
            leading=25,
            textColor=COLOR_NAVY,
            spaceBefore=8,
            spaceAfter=8,
        ),
        "h2": ParagraphStyle(
            "h2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=16,
            leading=20,
            textColor=COLOR_NAVY,
            spaceBefore=10,
            spaceAfter=7,
        ),
        "h3": ParagraphStyle(
            "h3",
            parent=base["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=12,
            leading=15,
            textColor=COLOR_TEAL,
            spaceBefore=8,
            spaceAfter=4,
        ),
        "body": ParagraphStyle(
            "body",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10.3,
            leading=15,
            textColor=COLOR_TEXT,
            spaceAfter=7,
        ),
        "bullet": ParagraphStyle(
            "bullet",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10.1,
            leading=14,
            textColor=COLOR_TEXT,
            leftIndent=0,
        ),
        "small": ParagraphStyle(
            "small",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=8.8,
            leading=11,
            textColor=COLOR_MUTED,
        ),
        "toc_item": ParagraphStyle(
            "toc_item",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10.5,
            leading=15,
            textColor=COLOR_TEXT,
            leftIndent=14,
            bulletIndent=0,
            spaceAfter=2,
        ),
        "legend_num": ParagraphStyle(
            "legend_num",
            parent=base["Normal"],
            fontName="Helvetica-Bold",
            fontSize=10,
            leading=12,
            textColor=COLOR_NAVY,
            alignment=1,
        ),
        "legend_text": ParagraphStyle(
            "legend_text",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=9.5,
            leading=13.5,
            textColor=COLOR_TEXT,
        ),
    }
    return styles


def add_cover(story: list, styles: dict[str, ParagraphStyle], generated_at: str) -> None:
    story.append(Spacer(1, 1.18 * inch))
    story.append(Paragraph("PAULT DOCUMENTATION", styles["cover_tag"]))
    story.append(Paragraph("User Guide", styles["cover_title"]))
    story.append(
        Paragraph(
            "Clean Technical edition for the current macOS app implementation.",
            styles["cover_subtitle"],
        )
    )

    chips = Table(
        [
            ["Main Window", "Menu Bar", "Hotkey Launcher", "Template Variables"],
        ],
        colWidths=[1.55 * inch, 1.3 * inch, 1.55 * inch, 1.8 * inch],
        hAlign="LEFT",
    )
    chips.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), COLOR_SURFACE),
                ("TEXTCOLOR", (0, 0), (-1, -1), COLOR_NAVY),
                ("FONTNAME", (0, 0), (-1, -1), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 8.8),
                ("LEFTPADDING", (0, 0), (-1, -1), 7),
                ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ("BOX", (0, 0), (-1, -1), 0.7, COLOR_LINE),
                ("INNERGRID", (0, 0), (-1, -1), 0.7, COLOR_LINE),
            ]
        )
    )
    story.append(chips)
    story.append(Spacer(1, 0.3 * inch))

    callout = Table(
        [
            [
                Paragraph(
                    (
                        "<b>Scope:</b> This guide reflects the app behavior currently implemented "
                        "in this repository, including template-variable parsing and resolved copy/paste flows."
                    ),
                    styles["body"],
                )
            ]
        ],
        colWidths=[6.45 * inch],
        hAlign="LEFT",
    )
    callout.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), COLOR_SURFACE),
                ("LEFTPADDING", (0, 0), (-1, -1), 12),
                ("RIGHTPADDING", (0, 0), (-1, -1), 12),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
                ("LINEBEFORE", (0, 0), (0, -1), 3, COLOR_TEAL),
                ("BOX", (0, 0), (-1, -1), 0.7, COLOR_LINE),
            ]
        )
    )
    story.append(callout)
    story.append(Spacer(1, 2.15 * inch))
    story.append(Paragraph(f"Generated: {generated_at}", styles["small"]))
    story.append(PageBreak())


def extract_h2_titles(markdown_text: str) -> list[str]:
    titles: list[str] = []
    for raw in markdown_text.splitlines():
        line = raw.strip()
        if line.startswith("## "):
            titles.append(line[3:].strip())
    return titles


def add_guide_map(story: list, styles: dict[str, ParagraphStyle], section_titles: Iterable[str]) -> None:
    story.append(Paragraph("Guide Map", styles["h1"]))
    story.append(
        Paragraph(
            "Use this map to jump directly to the workflow you need.",
            styles["body"],
        )
    )

    toc_items: list[ListItem] = []
    for title in section_titles:
        toc_items.append(
            ListItem(
                Paragraph(format_inline_markdown(title), styles["toc_item"]),
                leftIndent=2,
            )
        )
    story.append(
        ListFlowable(
            toc_items,
            bulletType="1",
            start="1",
            leftIndent=14,
            bulletFontName="Helvetica-Bold",
            bulletFontSize=9.5,
        )
    )
    story.append(Spacer(1, 0.18 * inch))


def parse_feature_matrix(path: Path) -> list[list[str]]:
    rows: list[list[str]] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        stripped = raw.strip()
        if not stripped.startswith("|"):
            continue
        parts = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(parts) < 4:
            continue
        if set(parts[0]) == {"-"}:
            continue
        rows.append(parts[:4])
    return rows


def add_feature_snapshot(story: list, styles: dict[str, ParagraphStyle], matrix_rows: list[list[str]]) -> None:
    if not matrix_rows:
        return

    story.append(Paragraph("Surface Capability Snapshot", styles["h2"]))
    story.append(
        Paragraph(
            "Current feature availability across the three app surfaces.",
            styles["body"],
        )
    )

    table_rows = [matrix_rows[0]] + matrix_rows[1:13]
    table = Table(
        table_rows,
        colWidths=[3.2 * inch, 1.0 * inch, 1.0 * inch, 1.2 * inch],
        repeatRows=1,
        hAlign="LEFT",
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), COLOR_NAVY),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, 0), 8.8),
                ("ALIGN", (1, 1), (-1, -1), "CENTER"),
                ("TEXTCOLOR", (0, 1), (-1, -1), COLOR_TEXT),
                ("FONTNAME", (0, 1), (-1, -1), "Helvetica"),
                ("FONTSIZE", (0, 1), (-1, -1), 8.4),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("GRID", (0, 0), (-1, -1), 0.5, COLOR_LINE),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, COLOR_SURFACE]),
            ]
        )
    )
    story.append(table)
    story.append(PageBreak())


def resolve_screenshot_path(screenshots_dir: Path, candidates: tuple[str, ...]) -> Path | None:
    for filename in candidates:
        path = screenshots_dir / filename
        if path.exists():
            return path
    return None


def build_callout_legend(
    callouts: tuple[CalloutSpec, ...],
    styles: dict[str, ParagraphStyle],
) -> Table:
    rows = []
    for callout in callouts:
        rows.append(
            [
                Paragraph(str(callout.number), styles["legend_num"]),
                Paragraph(
                    f"<b>{html.escape(callout.title)}:</b> {html.escape(callout.description)}",
                    styles["legend_text"],
                ),
            ]
        )

    legend = Table(rows, colWidths=[0.36 * inch, 6.09 * inch], hAlign="LEFT")
    legend.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, -1), COLOR_SURFACE),
                ("TEXTCOLOR", (0, 0), (-1, -1), COLOR_TEXT),
                ("LEFTPADDING", (0, 0), (-1, -1), 7),
                ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("GRID", (0, 0), (-1, -1), 0.5, COLOR_LINE),
                ("ROWBACKGROUNDS", (0, 0), (-1, -1), [colors.white, COLOR_SURFACE]),
            ]
        )
    )
    return legend


def add_visual_walkthrough(
    story: list,
    styles: dict[str, ParagraphStyle],
    screenshots_dir: Path,
) -> None:
    for index, spec in enumerate(SCREENSHOT_SPECS):
        image_path = resolve_screenshot_path(screenshots_dir, spec.candidate_filenames)
        story.append(Paragraph(spec.title, styles["h2"]))
        story.append(Paragraph(spec.subtitle, styles["body"]))
        story.append(
            AnnotatedScreenshot(
                image_path=image_path,
                callouts=spec.callouts,
                width=6.45 * inch,
                height=3.6 * inch,
            )
        )
        story.append(Spacer(1, 0.14 * inch))
        story.append(build_callout_legend(spec.callouts, styles))

        if image_path is None:
            expected = ", ".join(spec.candidate_filenames)
            story.append(Spacer(1, 0.08 * inch))
            story.append(
                Paragraph(
                    f"Expected screenshot file(s): <font name='Courier'>{html.escape(expected)}</font>",
                    styles["small"],
                )
            )

        if index != len(SCREENSHOT_SPECS) - 1:
            story.append(PageBreak())


def flush_bullets(story: list, styles: dict[str, ParagraphStyle], bullets: list[str]) -> None:
    if not bullets:
        return
    items = [
        ListItem(Paragraph(format_inline_markdown(item), styles["bullet"]), leftIndent=2)
        for item in bullets
    ]
    story.append(
        ListFlowable(
            items,
            bulletType="bullet",
            leftIndent=14,
            bulletFontName="Helvetica",
            bulletFontSize=10,
            bulletOffsetY=2,
        )
    )
    story.append(Spacer(1, 5))
    bullets.clear()


def add_markdown_content(
    story: list,
    styles: dict[str, ParagraphStyle],
    markdown_text: str,
    include_title_as_h1: bool,
) -> None:
    bullets: list[str] = []
    for raw in markdown_text.splitlines():
        line = raw.strip()
        if not line:
            flush_bullets(story, styles, bullets)
            continue

        if line.startswith("# "):
            flush_bullets(story, styles, bullets)
            if include_title_as_h1:
                story.append(Paragraph(format_inline_markdown(line[2:].strip()), styles["h1"]))
            continue

        if line.startswith("## "):
            flush_bullets(story, styles, bullets)
            story.append(Paragraph(format_inline_markdown(line[3:].strip()), styles["h2"]))
            continue

        if line.startswith("### "):
            flush_bullets(story, styles, bullets)
            story.append(Paragraph(format_inline_markdown(line[4:].strip()), styles["h3"]))
            continue

        if line.startswith("- "):
            bullets.append(line[2:].strip())
            continue

        flush_bullets(story, styles, bullets)
        story.append(Paragraph(format_inline_markdown(line), styles["body"]))

    flush_bullets(story, styles, bullets)


def draw_first_page(canvas, doc) -> None:
    canvas.saveState()
    canvas.setFillColor(COLOR_NAVY)
    canvas.rect(0, PAGE_HEIGHT - 1.45 * inch, PAGE_WIDTH, 1.45 * inch, stroke=0, fill=1)

    canvas.setFillColor(colors.white)
    canvas.setFont("Helvetica-Bold", 9)
    canvas.drawString(MARGIN_X, PAGE_HEIGHT - 0.62 * inch, "PAULT USER GUIDE")
    canvas.setFont("Helvetica", 8)
    canvas.drawRightString(PAGE_WIDTH - MARGIN_X, PAGE_HEIGHT - 0.62 * inch, "Clean Technical")

    canvas.setFillColor(COLOR_MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawRightString(PAGE_WIDTH - MARGIN_X, 0.38 * inch, f"Page {doc.page}")
    canvas.restoreState()


def draw_later_pages(canvas, doc) -> None:
    canvas.saveState()
    canvas.setStrokeColor(COLOR_LINE)
    canvas.setLineWidth(0.8)
    canvas.line(MARGIN_X, PAGE_HEIGHT - 0.53 * inch, PAGE_WIDTH - MARGIN_X, PAGE_HEIGHT - 0.53 * inch)

    canvas.setFillColor(COLOR_NAVY)
    canvas.setFont("Helvetica-Bold", 8.7)
    canvas.drawString(MARGIN_X, PAGE_HEIGHT - 0.43 * inch, "PAULT USER GUIDE")

    canvas.setFillColor(COLOR_MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawRightString(PAGE_WIDTH - MARGIN_X, PAGE_HEIGHT - 0.43 * inch, "Clean Technical")
    canvas.drawRightString(PAGE_WIDTH - MARGIN_X, 0.38 * inch, f"Page {doc.page}")
    canvas.restoreState()


def generate_user_guide_pdf(output_path: Path, screenshots_dir: Path) -> Path:
    user_guide_md = (DOCS_DIR / "USER_GUIDE.md").read_text(encoding="utf-8")
    troubleshooting_md = (DOCS_DIR / "TROUBLESHOOTING.md").read_text(encoding="utf-8")
    matrix_rows = parse_feature_matrix(DOCS_DIR / "FEATURE_MATRIX.md")

    styles = build_styles()
    generated_at = datetime.now().strftime("%B %d, %Y")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=LETTER,
        leftMargin=MARGIN_X,
        rightMargin=MARGIN_X,
        topMargin=MARGIN_TOP,
        bottomMargin=MARGIN_BOTTOM,
        title="Pault User Guide",
        author="Pault",
    )

    story: list = []
    add_cover(story, styles, generated_at)
    add_guide_map(story, styles, extract_h2_titles(user_guide_md))
    add_feature_snapshot(story, styles, matrix_rows)
    add_visual_walkthrough(story, styles, screenshots_dir)
    story.append(PageBreak())
    add_markdown_content(story, styles, user_guide_md, include_title_as_h1=True)
    story.append(Spacer(1, 0.1 * inch))
    story.append(
        Table(
            [[Paragraph("", styles["small"])]],
            colWidths=[6.45 * inch],
            hAlign="LEFT",
            style=TableStyle(
                [
                    ("LINEABOVE", (0, 0), (-1, 0), 1, COLOR_LINE),
                    ("TOPPADDING", (0, 0), (-1, 0), 3),
                    ("BOTTOMPADDING", (0, 0), (-1, 0), 0),
                ]
            ),
        )
    )
    story.append(Spacer(1, 0.12 * inch))
    add_markdown_content(story, styles, troubleshooting_md, include_title_as_h1=True)

    doc.build(
        story,
        onFirstPage=draw_first_page,
        onLaterPages=draw_later_pages,
    )
    return output_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the stylized User Guide PDF.")
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output PDF path (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--screenshots-dir",
        type=Path,
        default=DOCS_DIR / "app-store" / "screenshots",
        help="Directory containing app screenshots used for visual walkthrough pages.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output = generate_user_guide_pdf(args.output, args.screenshots_dir)
    print(f"Generated {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
