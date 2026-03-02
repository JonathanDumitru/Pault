#!/usr/bin/env python3
"""
Build a stylized PDF bundle from markdown files in docs/.

Outputs:
  - One PDF per markdown file, mirrored under output/pdf/docs-stylized/
  - A diagram catalog PDF embedding docs/diagrams/exports/*.png
  - A bundle index PDF listing all generated artifacts
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
    Image,
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
DEFAULT_OUTPUT_DIR = ROOT / "output" / "pdf" / "docs-stylized"

PAGE_WIDTH, PAGE_HEIGHT = LETTER
MARGIN_X = 0.82 * inch
MARGIN_TOP = 0.9 * inch
MARGIN_BOTTOM = 0.72 * inch

COLOR_NAVY = colors.HexColor("#102A43")
COLOR_TEAL = colors.HexColor("#1F7A8C")
COLOR_TEXT = colors.HexColor("#1F2933")
COLOR_MUTED = colors.HexColor("#52606D")
COLOR_LINE = colors.HexColor("#D9E2EC")
COLOR_SURFACE = colors.HexColor("#F7FAFC")


@dataclass(frozen=True)
class BuildResult:
    source_md: Path
    output_pdf: Path


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
        "cover_tag": ParagraphStyle(
            "cover_tag",
            parent=base["Normal"],
            fontName="Helvetica-Bold",
            fontSize=10,
            leading=12,
            textColor=COLOR_TEAL,
            spaceAfter=10,
        ),
        "cover_title": ParagraphStyle(
            "cover_title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=30,
            leading=34,
            textColor=COLOR_NAVY,
            spaceAfter=8,
        ),
        "cover_subtitle": ParagraphStyle(
            "cover_subtitle",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=12,
            leading=17,
            textColor=COLOR_MUTED,
            spaceAfter=12,
        ),
        "h1": ParagraphStyle(
            "h1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=20,
            leading=24,
            textColor=COLOR_NAVY,
            spaceBefore=8,
            spaceAfter=8,
        ),
        "h2": ParagraphStyle(
            "h2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=15,
            leading=19,
            textColor=COLOR_NAVY,
            spaceBefore=10,
            spaceAfter=7,
        ),
        "h3": ParagraphStyle(
            "h3",
            parent=base["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=11.5,
            leading=15,
            textColor=COLOR_TEAL,
            spaceBefore=8,
            spaceAfter=4,
        ),
        "body": ParagraphStyle(
            "body",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10.2,
            leading=14.6,
            textColor=COLOR_TEXT,
            spaceAfter=6,
        ),
        "bullet": ParagraphStyle(
            "bullet",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10,
            leading=14,
            textColor=COLOR_TEXT,
            leftIndent=0,
        ),
        "small": ParagraphStyle(
            "small",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=8.6,
            leading=11,
            textColor=COLOR_MUTED,
        ),
        "code": ParagraphStyle(
            "code",
            parent=base["Code"],
            fontName="Courier",
            fontSize=8.8,
            leading=11.2,
            textColor=COLOR_TEXT,
            backColor=COLOR_SURFACE,
            leftIndent=8,
            rightIndent=8,
            borderWidth=0.5,
            borderColor=COLOR_LINE,
            borderPadding=5,
            spaceAfter=6,
        ),
        "index_item": ParagraphStyle(
            "index_item",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=9.6,
            leading=13,
            textColor=COLOR_TEXT,
            leftIndent=14,
            bulletIndent=0,
            spaceAfter=2,
        ),
    }


def draw_first_page(canvas, doc) -> None:
    canvas.saveState()
    canvas.setFillColor(COLOR_NAVY)
    canvas.rect(0, PAGE_HEIGHT - 1.4 * inch, PAGE_WIDTH, 1.4 * inch, stroke=0, fill=1)
    canvas.setFillColor(colors.white)
    canvas.setFont("Helvetica-Bold", 9)
    canvas.drawString(MARGIN_X, PAGE_HEIGHT - 0.6 * inch, "PAULT DOCS")
    canvas.setFont("Helvetica", 8)
    canvas.drawRightString(PAGE_WIDTH - MARGIN_X, PAGE_HEIGHT - 0.6 * inch, "Stylized Bundle")
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
    canvas.setFont("Helvetica-Bold", 8.6)
    canvas.drawString(MARGIN_X, PAGE_HEIGHT - 0.43 * inch, "PAULT DOCS")
    canvas.setFillColor(COLOR_MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawRightString(PAGE_WIDTH - MARGIN_X, PAGE_HEIGHT - 0.43 * inch, "Stylized Bundle")
    canvas.drawRightString(PAGE_WIDTH - MARGIN_X, 0.38 * inch, f"Page {doc.page}")
    canvas.restoreState()


def add_cover(story: list, styles: dict[str, ParagraphStyle], title: str, subtitle: str, generated_at: str) -> None:
    story.append(Spacer(1, 1.1 * inch))
    story.append(Paragraph("PAULT DOCUMENTATION", styles["cover_tag"]))
    story.append(Paragraph(format_inline_markdown(title), styles["cover_title"]))
    story.append(Paragraph(format_inline_markdown(subtitle), styles["cover_subtitle"]))
    card = Table(
        [[Paragraph("<b>Theme:</b> Clean Technical", styles["body"])]],
        colWidths=[6.5 * inch],
        hAlign="LEFT",
    )
    card.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), COLOR_SURFACE),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ("LINEBEFORE", (0, 0), (0, -1), 3, COLOR_TEAL),
                ("BOX", (0, 0), (-1, -1), 0.7, COLOR_LINE),
            ]
        )
    )
    story.append(card)
    story.append(Spacer(1, 2.4 * inch))
    story.append(Paragraph(f"Generated: {generated_at}", styles["small"]))
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
    story.append(Spacer(1, 4))
    bullets.clear()


def flush_code_block(story: list, styles: dict[str, ParagraphStyle], code_lines: list[str]) -> None:
    if not code_lines:
        return
    escaped = "<br/>".join(html.escape(line) for line in code_lines)
    story.append(Paragraph(escaped, styles["code"]))
    code_lines.clear()


def add_markdown_content(story: list, styles: dict[str, ParagraphStyle], markdown_text: str) -> None:
    bullets: list[str] = []
    code_lines: list[str] = []
    in_code_block = False

    for raw in markdown_text.splitlines():
        line = raw.rstrip("\n")
        stripped = line.strip()

        if stripped.startswith("```"):
            flush_bullets(story, styles, bullets)
            if in_code_block:
                flush_code_block(story, styles, code_lines)
                in_code_block = False
            else:
                in_code_block = True
            continue

        if in_code_block:
            code_lines.append(line)
            continue

        if not stripped:
            flush_bullets(story, styles, bullets)
            continue

        if stripped.startswith("# "):
            flush_bullets(story, styles, bullets)
            story.append(Paragraph(format_inline_markdown(stripped[2:].strip()), styles["h1"]))
            continue
        if stripped.startswith("## "):
            flush_bullets(story, styles, bullets)
            story.append(Paragraph(format_inline_markdown(stripped[3:].strip()), styles["h2"]))
            continue
        if stripped.startswith("### "):
            flush_bullets(story, styles, bullets)
            story.append(Paragraph(format_inline_markdown(stripped[4:].strip()), styles["h3"]))
            continue

        if re.match(r"^\d+\.\s+", stripped):
            flush_bullets(story, styles, bullets)
            story.append(Paragraph(format_inline_markdown(stripped), styles["body"]))
            continue

        if stripped.startswith("- "):
            bullets.append(stripped[2:].strip())
            continue

        flush_bullets(story, styles, bullets)
        story.append(Paragraph(format_inline_markdown(stripped), styles["body"]))

    flush_code_block(story, styles, code_lines)
    flush_bullets(story, styles, bullets)


def markdown_files(docs_dir: Path) -> list[Path]:
    files = sorted(
        [
            path
            for path in docs_dir.rglob("*.md")
            if path.is_file()
        ]
    )
    return files


def build_single_doc_pdf(md_path: Path, output_pdf: Path, styles: dict[str, ParagraphStyle]) -> None:
    generated_at = datetime.now().strftime("%B %d, %Y")
    title_guess = md_path.stem.replace("-", " ").replace("_", " ").title()
    subtitle = f"Source: {md_path.relative_to(ROOT)}"
    markdown_text = md_path.read_text(encoding="utf-8")

    output_pdf.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(output_pdf),
        pagesize=LETTER,
        leftMargin=MARGIN_X,
        rightMargin=MARGIN_X,
        topMargin=MARGIN_TOP,
        bottomMargin=MARGIN_BOTTOM,
        title=title_guess,
        author="Pault",
    )

    story: list = []
    add_cover(story, styles, title_guess, subtitle, generated_at)
    add_markdown_content(story, styles, markdown_text)

    doc.build(story, onFirstPage=draw_first_page, onLaterPages=draw_later_pages)


def build_diagrams_catalog(output_pdf: Path, styles: dict[str, ParagraphStyle]) -> None:
    diagram_dir = DOCS_DIR / "diagrams" / "exports"
    pngs = sorted(diagram_dir.glob("*.png"))
    generated_at = datetime.now().strftime("%B %d, %Y")

    output_pdf.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(output_pdf),
        pagesize=LETTER,
        leftMargin=MARGIN_X,
        rightMargin=MARGIN_X,
        topMargin=MARGIN_TOP,
        bottomMargin=MARGIN_BOTTOM,
        title="Pault Diagram Catalog",
        author="Pault",
    )
    story: list = []
    add_cover(
        story,
        styles,
        "Diagram Catalog",
        "Exported architecture and workflow diagrams from docs/diagrams/exports",
        generated_at,
    )

    if not pngs:
        story.append(Paragraph("No exported diagram PNG files found.", styles["body"]))
    else:
        for i, png in enumerate(pngs):
            story.append(Paragraph(png.name, styles["h2"]))
            reader = ImageReader(str(png))
            img_w, img_h = reader.getSize()
            max_w = 6.5 * inch
            max_h = 8.0 * inch
            scale = min(max_w / img_w, max_h / img_h)
            story.append(Image(str(png), width=img_w * scale, height=img_h * scale))
            story.append(Spacer(1, 0.14 * inch))
            story.append(Paragraph(f"Source: {png.relative_to(ROOT)}", styles["small"]))
            if i != len(pngs) - 1:
                story.append(PageBreak())

    doc.build(story, onFirstPage=draw_first_page, onLaterPages=draw_later_pages)


def build_bundle_index(output_pdf: Path, built_docs: list[BuildResult], styles: dict[str, ParagraphStyle]) -> None:
    generated_at = datetime.now().strftime("%B %d, %Y")
    output_pdf.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(output_pdf),
        pagesize=LETTER,
        leftMargin=MARGIN_X,
        rightMargin=MARGIN_X,
        topMargin=MARGIN_TOP,
        bottomMargin=MARGIN_BOTTOM,
        title="Stylized Docs Bundle Index",
        author="Pault",
    )
    story: list = []
    add_cover(
        story,
        styles,
        "Comprehensive Docs Bundle",
        "Stylized PDF outputs generated from docs markdown and diagram exports",
        generated_at,
    )
    story.append(Paragraph("Generated Documents", styles["h1"]))
    items = []
    for item in built_docs:
        label = f"{item.source_md.relative_to(ROOT)} -> {item.output_pdf.relative_to(ROOT)}"
        items.append(ListItem(Paragraph(format_inline_markdown(label), styles["index_item"]), leftIndent=2))
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
    doc.build(story, onFirstPage=draw_first_page, onLaterPages=draw_later_pages)


def to_output_path(md_path: Path, output_dir: Path) -> Path:
    rel = md_path.relative_to(DOCS_DIR)
    return output_dir / rel.with_suffix(".pdf")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build stylized PDF bundle from docs markdown.")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"Output directory (default: {DEFAULT_OUTPUT_DIR})",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    styles = build_styles()
    output_dir: Path = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    built_docs: list[BuildResult] = []
    for md in markdown_files(DOCS_DIR):
        out = to_output_path(md, output_dir)
        build_single_doc_pdf(md, out, styles)
        built_docs.append(BuildResult(source_md=md, output_pdf=out))

    diagrams_pdf = output_dir / "diagrams" / "DIAGRAMS_CATALOG.pdf"
    build_diagrams_catalog(diagrams_pdf, styles)
    built_docs.append(
        BuildResult(
            source_md=DOCS_DIR / "diagrams" / "exports",
            output_pdf=diagrams_pdf,
        )
    )

    index_pdf = output_dir / "INDEX.pdf"
    build_bundle_index(index_pdf, built_docs, styles)

    print(f"Generated {len(built_docs)} stylized PDF artifacts in {output_dir}")
    print(f"Index: {index_pdf}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
