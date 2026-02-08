#!/usr/bin/env python3
"""Render Mermaid diagrams in docs/diagrams to PNG exports."""
from __future__ import annotations

import os
import pathlib
import shutil
import subprocess
import sys


def main() -> int:
    repo_root = pathlib.Path(__file__).resolve().parents[1]
    diagrams_dir = repo_root / "docs" / "diagrams"
    exports_dir = diagrams_dir / "exports"
    exports_dir.mkdir(parents=True, exist_ok=True)

    mmdc = shutil.which("mmdc")
    if not mmdc:
        print("mmdc (mermaid-cli) not found. Install @mermaid-js/mermaid-cli to render PNGs.", file=sys.stderr)
        return 1

    diagram_files = sorted(diagrams_dir.glob("*.mmd"))
    if not diagram_files:
        print("No .mmd files found in docs/diagrams.")
        return 0

    puppeteer_config = os.environ.get("MERMAID_PUPPETEER_CONFIG")

    for diagram in diagram_files:
        output_path = exports_dir / f"{diagram.stem}.png"
        cmd = [mmdc]
        if puppeteer_config:
            cmd.extend(["-p", puppeteer_config])
        cmd.extend(["-i", str(diagram), "-o", str(output_path)])
        subprocess.run(cmd, check=True)
        print(f"Rendered {diagram.name} -> {output_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
