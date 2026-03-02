#!/usr/bin/env python3
"""
Generate a stylized "Clean Technical" PDF for the Schemap user documentation.

Usage:
  .venv/bin/python scripts/pdf/build_schemap_user_guide_pdf.py
  .venv/bin/python scripts/pdf/build_schemap_user_guide_pdf.py --output output/pdf/custom-name.pdf
"""

from __future__ import annotations

import argparse
import html
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

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
DOCS_DIR = ROOT / "Schemap" / "docs"
DEFAULT_OUTPUT = ROOT / "output" / "pdf" / "schemap-user-guide-clean-technical.pdf"

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
    anchor_x: float
    anchor_y: float
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
        title="Build Tab Overview",
        subtitle="Three-pane workspace for block composition, preview, and registry.",
        candidate_filenames=("01-build-overview.png",),
        callouts=(
            CalloutSpec(1, 0.12, 0.78, "Block library", "Browse categories and add blocks."),
            CalloutSpec(2, 0.45, 0.62, "Composition canvas", "Arrange and edit blocks in sequence."),
            CalloutSpec(3, 0.82, 0.78, "Preview", "Review compiled prompt output and token estimate."),
            CalloutSpec(4, 0.82, 0.24, "Registry", "Manage reusable projects, snippets, and policies."),
        ),
    ),
    ScreenshotSpec(
        title="Editing Blocks In Canvas",
        subtitle="Inline placeholders and drag-based ordering in the Build workflow.",
        candidate_filenames=("02-block-input-editing.png",),
        callouts=(
            CalloutSpec(1, 0.48, 0.74, "Selected block", "Current block is focused for editing."),
            CalloutSpec(2, 0.58, 0.52, "Inline inputs", "Fill placeholders directly in the canvas."),
            CalloutSpec(3, 0.37, 0.36, "Reorder flow", "Drag blocks to change compiled order."),
        ),
    ),
    ScreenshotSpec(
        title="Preview, Copy, And Export",
        subtitle="Compiled output panel and quick export actions.",
        candidate_filenames=("03-preview-copy-export.png",),
        callouts=(
            CalloutSpec(1, 0.82, 0.76, "Compiled preview", "Live output generated from current blocks."),
            CalloutSpec(2, 0.52, 0.09, "Copy", "Copy compiled prompt to clipboard."),
            CalloutSpec(3, 0.62, 0.09, "Export", "Export prompt as PDF/Markdown/Text."),
        ),
    ),
    ScreenshotSpec(
        title="Registry Workflow",
        subtitle="Reusable object management for projects, snippets, variables, personas, and policies.",
        candidate_filenames=("04-registry-projects-snippets.png",),
        callouts=(
            CalloutSpec(1, 0.75, 0.31, "Object type", "Switch registry category in the picker."),
            CalloutSpec(2, 0.84, 0.22, "Object list", "Select a reusable object."),
            CalloutSpec(3, 0.84, 0.09, "Inspector/editor", "View and edit object details."),
        ),
    ),
    ScreenshotSpec(
        title="Command Palette",
        subtitle="Keyboard-first command discovery and execution.",
        candidate_filenames=("05-command-palette.png",),
        callouts=(
            CalloutSpec(1, 0.50, 0.83, "Search", "Filter commands by name."),
            CalloutSpec(2, 0.50, 0.58, "Command results", "Run common actions without menu navigation."),
        ),
    ),
    ScreenshotSpec(
        title="Variants Tab",
        subtitle="Generate and compare alternative prompt versions.",
        candidate_filenames=("06-variants-tab.png",),
        callouts=(
            CalloutSpec(1, 0.20, 0.84, "Variant controls", "Generate alternatives from current prompt."),
            CalloutSpec(2, 0.52, 0.56, "Variant content", "Inspect the selected variant output."),
        ),
    ),
    ScreenshotSpec(
        title="Exports Tab",
        subtitle="Track and configure prompt exports.",
        candidate_filenames=("07-exports-tab.png",),
        callouts=(
            CalloutSpec(1, 0.25, 0.82, "Format options", "Choose output format and export mode."),
            CalloutSpec(2, 0.55, 0.42, "Export history", "Review recent exports and destinations."),
        ),
    ),
)


class AnnotatedScreenshot(Flowable):
    def __init__(self, image_path: Path | None, callouts: tuple[CalloutSpec, ...], width: float, height: float) -> None:
        super().__init__()
        self.image_path = image_path
        self.callouts = callouts
        self.width = width
        self.height = height

    def wrap(self, availWidth, availHeight):
        return self.width, self.height

    def draw(self) -> None:
        c = self.canv
        c.setFillColor(colors.white)
        c.setStrokeColor(COLOR_LINE)
        c.setLineWidth(0.8)
        c.roundRect(0, 0, self.width, self.height, 7, stroke=1, fill=1)

        padding = 6
        pane_x = padding
        pane_y = padding
        pane_w = self.width - (2 * padding)
        pane_h = self.height - (2 * padding)
        image_x, image_y, image_w, image_h = pane_x, pane_y, pane_w, pane_h

        if self.image_path and self.image_path.exists():
            reader = ImageReader(str(self.image_path))
            raw_w, raw_h = reader.getSize()
            scale = min(pane_w / raw_w, pane_h / raw_h)
            draw_w = raw_w * scale
            draw_h = raw_h * scale
            image_x = pane_x + (pane_w - draw_w) / 2
            image_y = pane_y + (pane_h - draw_h) / 2
            image_w, image_h = draw_w, draw_h
            c.drawImage(reader, image_x, image_y, width=image_w, height=image_h, preserveAspectRatio=True, mask="auto")
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
                "Screenshot not found. Add PNG in Schemap/docs/screenshots/",
            )

        for callout in self.callouts:
            cx = image_x + callout.anchor_x * image_w
            cy = image_y + callout.anchor_y * image_h
            c.setFillColor(COLOR_TEAL)
            c.circle(cx, cy, 9, stroke=0, fill=1)
            c.setFillColor(colors.white)
            c.setFont("Helvetica-Bold", 8)
            c.drawCentredString(cx, cy - 2.8, str(callout.number))


def format_inline_markdown(text: str) -> str:
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
    return {
        "cover_tag": ParagraphStyle("cover_tag", parent=base["Normal"], fontName="Helvetica-Bold", fontSize=10, leading=12, textColor=COLOR_TEAL, spaceAfter=10, uppercase=True),
        "cover_title": ParagraphStyle("cover_title", parent=base["Title"], fontName="Helvetica-Bold", fontSize=34, leading=38, textColor=COLOR_NAVY, spaceAfter=8),
        "cover_subtitle": ParagraphStyle("cover_subtitle", parent=base["Normal"], fontName="Helvetica", fontSize=13, leading=18, textColor=COLOR_MUTED, spaceAfter=14),
        "h1": ParagraphStyle("h1", parent=base["Heading1"], fontName="Helvetica-Bold", fontSize=21, leading=25, textColor=COLOR_NAVY, spaceBefore=8, spaceAfter=8),
        "h2": ParagraphStyle("h2", parent=base["Heading2"], fontName="Helvetica-Bold", fontSize=16, leading=20, textColor=COLOR_NAVY, spaceBefore=10, spaceAfter=7),
        "h3": ParagraphStyle("h3", parent=base["Heading3"], fontName="Helvetica-Bold", fontSize=12, leading=15, textColor=COLOR_TEAL, spaceBefore=8, spaceAfter=4),
        "body": ParagraphStyle("body", parent=base["Normal"], fontName="Helvetica", fontSize=10.3, leading=15, textColor=COLOR_TEXT, spaceAfter=7),
        "bullet": ParagraphStyle("bullet", parent=base["Normal"], fontName="Helvetica", fontSize=10.1, leading=14, textColor=COLOR_TEXT, leftIndent=0),
        "small": ParagraphStyle("small", parent=base["Normal"], fontName="Helvetica", fontSize=8.8, leading=11, textColor=COLOR_MUTED),
        "toc_item": ParagraphStyle("toc_item", parent=base["Normal"], fontName="Helvetica", fontSize=10.5, leading=15, textColor=COLOR_TEXT, leftIndent=14, bulletIndent=0, spaceAfter=2),
        "legend_num": ParagraphStyle("legend_num", parent=base["Normal"], fontName="Helvetica-Bold", fontSize=10, leading=12, textColor=COLOR_NAVY, alignment=1),
        "legend_text": ParagraphStyle("legend_text", parent=base["Normal"], fontName="Helvetica", fontSize=9.5, leading=13.5, textColor=COLOR_TEXT),
    }


def extract_h2_titles(markdown_text: str) -> list[str]:
    return [line.strip()[3:].strip() for line in markdown_text.splitlines() if line.strip().startswith("## ")]


def add_cover(story: list, styles: dict[str, ParagraphStyle], generated_at: str) -> None:
    story.append(Spacer(1, 1.18 * inch))
    story.append(Paragraph("SCHEMAP DOCUMENTATION", styles["cover_tag"]))
    story.append(Paragraph("User Guide", styles["cover_title"]))
    story.append(Paragraph("Clean Technical edition for the current macOS app implementation.", styles["cover_subtitle"]))

    chips = Table(
        [["Build Tab", "Variants", "Exports", "Registry"]],
        colWidths=[1.6 * inch, 1.3 * inch, 1.3 * inch, 2.0 * inch],
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
    story.append(Paragraph(f"Generated: {generated_at}", styles["small"]))
    story.append(PageBreak())


def add_guide_map(story: list, styles: dict[str, ParagraphStyle], titles: list[str]) -> None:
    story.append(Paragraph("Guide Map", styles["h1"]))
    story.append(Paragraph("Use this map to jump directly to the workflow you need.", styles["body"]))
    items = [ListItem(Paragraph(format_inline_markdown(t), styles["toc_item"]), leftIndent=2) for t in titles]
    story.append(
        ListFlowable(
            items,
            bulletType="1",
            start="1",
            leftIndent=14,
            bulletFontName="Helvetica-Bold",
            bulletFontSize=9.5,
        )
    )
    story.append(PageBreak())


def resolve_screenshot_path(screenshots_dir: Path, candidates: tuple[str, ...]) -> Path | None:
    for filename in candidates:
        path = screenshots_dir / filename
        if path.exists():
            return path
    return None


def build_callout_legend(callouts: tuple[CalloutSpec, ...], styles: dict[str, ParagraphStyle]) -> Table:
    rows = []
    for callout in callouts:
        rows.append(
            [
                Paragraph(str(callout.number), styles["legend_num"]),
                Paragraph(f"<b>{html.escape(callout.title)}:</b> {html.escape(callout.description)}", styles["legend_text"]),
            ]
        )
    table = Table(rows, colWidths=[0.36 * inch, 6.09 * inch], hAlign="LEFT")
    table.setStyle(
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
    return table


def add_visual_walkthrough(story: list, styles: dict[str, ParagraphStyle], screenshots_dir: Path) -> None:
    for index, spec in enumerate(SCREENSHOT_SPECS):
        image_path = resolve_screenshot_path(screenshots_dir, spec.candidate_filenames)
        story.append(Paragraph(spec.title, styles["h2"]))
        story.append(Paragraph(spec.subtitle, styles["body"]))
        story.append(AnnotatedScreenshot(image_path, spec.callouts, width=6.45 * inch, height=3.6 * inch))
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
    items = [ListItem(Paragraph(format_inline_markdown(item), styles["bullet"]), leftIndent=2) for item in bullets]
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


def add_markdown_content(story: list, styles: dict[str, ParagraphStyle], markdown_text: str, include_title_as_h1: bool) -> None:
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
    canvas.drawString(MARGIN_X, PAGE_HEIGHT - 0.62 * inch, "SCHEMAP USER GUIDE")
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
    canvas.drawString(MARGIN_X, PAGE_HEIGHT - 0.43 * inch, "SCHEMAP USER GUIDE")
    canvas.setFillColor(COLOR_MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawRightString(PAGE_WIDTH - MARGIN_X, PAGE_HEIGHT - 0.43 * inch, "Clean Technical")
    canvas.drawRightString(PAGE_WIDTH - MARGIN_X, 0.38 * inch, f"Page {doc.page}")
    canvas.restoreState()


def generate_user_guide_pdf(output_path: Path, screenshots_dir: Path) -> Path:
    user_guide_md = (DOCS_DIR / "USER_GUIDE.md").read_text(encoding="utf-8")
    troubleshooting_md = (DOCS_DIR / "TROUBLESHOOTING.md").read_text(encoding="utf-8")
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
        title="Schemap User Guide",
        author="Schemap",
    )

    story: list = []
    add_cover(story, styles, generated_at)
    add_guide_map(story, styles, extract_h2_titles(user_guide_md))
    add_visual_walkthrough(story, styles, screenshots_dir)
    story.append(PageBreak())
    add_markdown_content(story, styles, user_guide_md, include_title_as_h1=True)
    story.append(Spacer(1, 0.12 * inch))
    add_markdown_content(story, styles, troubleshooting_md, include_title_as_h1=True)

    doc.build(story, onFirstPage=draw_first_page, onLaterPages=draw_later_pages)
    return output_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the stylized Schemap User Guide PDF.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help=f"Output PDF path (default: {DEFAULT_OUTPUT})")
    parser.add_argument(
        "--screenshots-dir",
        type=Path,
        default=DOCS_DIR / "screenshots",
        help="Directory containing screenshots used in visual walkthrough pages.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output = generate_user_guide_pdf(args.output, args.screenshots_dir)
    print(f"Generated {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
