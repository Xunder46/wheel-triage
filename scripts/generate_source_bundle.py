#!/usr/bin/env python3
"""Create a focused source bundle for the app without including project config."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path

EXCLUDED_DIRS = {
    ".git",
    ".hg",
    ".svn",
    ".idea",
    ".vscode",
    ".dart_tool",
    ".claude",
    "artifacts",
    "build",
    "node_modules",
    "__pycache__",
    ".venv",
    "venv",
    "android",
    "ios",
    "macos",
    "linux",
    "windows",
    "web",
}

EXCLUDED_FILES = {
    "pubspec.yaml",
    "pubspec.lock",
    "analysis_options.yaml",
    ".gitignore",
    ".metadata",
    "*.iml",
    "flutter_test_config.yaml",
    "dart_test.yaml",
}

INCLUDED_ROOT_FILES = {"README.md", "CLAUDE.md"}


def is_excluded_file(rel_path: Path) -> bool:
    if rel_path.name in EXCLUDED_FILES:
        return True
    if rel_path.suffix.lower() in {".lock", ".iml", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".ico", ".bmp", ".pdf"}:
        return True
    return False


def should_include(path: Path, root: Path) -> bool:
    rel_path = path.relative_to(root)

    if rel_path.is_absolute():
        return False

    if any(part in EXCLUDED_DIRS for part in rel_path.parts[:-1]):
        return False

    if is_excluded_file(rel_path):
        return False

    if rel_path.parts and rel_path.parts[0] in {"lib", "test"}:
        return True

    if rel_path.parts and rel_path.parts[0] == "docs":
        return rel_path.suffix.lower() in {".md", ".txt"}

    if rel_path.name in INCLUDED_ROOT_FILES:
        return True

    return False


def gather_source_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if should_include(path, root):
            files.append(path)
    files.sort()
    return files


def create_bundle(root: Path, output_path: Path) -> None:
    files = gather_source_files(root)
    if not files:
        raise FileNotFoundError(f"No source files matched the bundle rules in {root}")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    lines: list[str] = [
        "Wheel Triage source bundle",
        f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S %Z')}",
        f"Included files: {len(files)}",
        "",
    ]

    for file_path in files:
        rel_path = file_path.relative_to(root).as_posix()
        lines.append(f"===== FILE: {rel_path} =====")
        try:
            text = file_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = file_path.read_bytes().decode("utf-8", errors="replace")
        text = text.rstrip()
        lines.append(text)
        lines.append("")
        lines.append("===== END FILE =====")
        lines.append("")

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Created source bundle: {output_path}")
    print(f"Included {len(files)} files.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root to scan. Defaults to the parent of this script.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output text file path. Defaults to ./artifacts/source_bundle_<timestamp>.txt.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    root = args.root.resolve()
    if args.output is None:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        output_path = root / "artifacts" / f"source_bundle_{timestamp}.txt"
    else:
        output_path = args.output.resolve()

    create_bundle(root, output_path)


if __name__ == "__main__":
    main()
