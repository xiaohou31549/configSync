#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARCH_PATH = ROOT / "docs" / "ARCHITECTURE.md"
AGENTS_PATH = ROOT / "AGENTS.md"
PROJECT_YML = ROOT / "project.yml"
PACKAGE_SWIFT = ROOT / "Package.swift"


def fail(message: str) -> None:
    print(f"doc-gardening 失败：{message}", file=sys.stderr)
    sys.exit(1)


def read_required(path: Path) -> str:
    if not path.exists():
        fail(f"缺少文件：{path}")
    return path.read_text(encoding="utf-8")


def build_generated_block() -> str:
    package_text = read_required(PACKAGE_SWIFT)
    project_text = read_required(PROJECT_YML)

    swift_tools = re.search(r"swift-tools-version:\s*([0-9.]+)", package_text)
    deployment = re.search(r'macOS:\s*"([^"]+)"', project_text)
    targets = re.findall(r"^  ([A-Za-z0-9_]+):\n    type:", project_text, flags=re.MULTILINE)
    scripts = sorted(path.name for path in (ROOT / "scripts").glob("*") if path.is_file())
    docs = sorted(path.name for path in (ROOT / "docs").glob("*.md"))

    lines = [
        "_由 `python3 scripts/doc_gardening.py` 维护，请勿手改此区块。_",
        f"- Swift tools version：{swift_tools.group(1) if swift_tools else 'unknown'}",
        f"- macOS deployment target：{deployment.group(1) if deployment else 'unknown'}",
        f"- Xcode targets：{', '.join(targets) if targets else 'unknown'}",
        f"- Scripts：{', '.join(scripts) if scripts else 'none'}",
        f"- Docs：{', '.join(docs) if docs else 'none'}",
        "- 关键校验入口：`./init.sh`、`./scripts/check_architecture.sh`、`python3 scripts/validate_feature_list.py feature_list.json`"
    ]
    return "\n".join(lines)


def update_architecture(check: bool) -> None:
    text = read_required(ARCH_PATH)
    begin = "<!-- GENERATED:BEGIN -->"
    end = "<!-- GENERATED:END -->"
    if begin not in text or end not in text:
        fail("ARCHITECTURE.md 缺少 GENERATED 标记")

    generated = build_generated_block()
    replacement = f"{begin}\n{generated}\n{end}"
    updated = re.sub(
        rf"{re.escape(begin)}.*?{re.escape(end)}",
        replacement,
        text,
        count=1,
        flags=re.DOTALL,
    )

    if check and updated != text:
        fail("ARCHITECTURE.md 的自动生成区块已过期。修复方法：运行 `python3 scripts/doc_gardening.py`")

    if not check and updated != text:
        ARCH_PATH.write_text(updated, encoding="utf-8")


def validate_index_files() -> None:
    for path in [
        ROOT / "docs" / "README.md",
        ROOT / "docs" / "PRODUCT_SPEC.md",
        ROOT / "docs" / "EXECUTION_PLAN.md",
        ROOT / "docs" / "HARNESS_ENGINEERING.md",
        ROOT / "docs" / "TESTING_STRATEGY.md",
        ROOT / "docs" / "DATABASE_SCHEMA.md",
        ROOT / "project-progress.txt",
        ROOT / "feature_list.json",
    ]:
        if not path.exists():
            fail(f"缺少 Harness 关键文件：{path}")

    agents_text = read_required(AGENTS_PATH)
    line_count = len(agents_text.splitlines())
    if line_count > 140:
        fail(f"AGENTS.md 过长（{line_count} 行）。修复方法：将其压缩成目录索引，而不是详细手册")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="只校验，不写回文件")
    args = parser.parse_args()

    validate_index_files()
    update_architecture(check=args.check)
    print("doc-gardening 完成")


if __name__ == "__main__":
    main()
