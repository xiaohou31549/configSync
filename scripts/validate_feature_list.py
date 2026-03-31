#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

REQUIRED_KEYS = {"id", "title", "priority", "area", "description", "verification", "passes"}


def fail(message: str) -> None:
    print(f"feature_list 校验失败：{message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("用法：python3 scripts/validate_feature_list.py feature_list.json")

    path = Path(sys.argv[1])
    if not path.exists():
        fail(f"文件不存在：{path}")

    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"JSON 解析失败：{exc}")

    if not isinstance(payload, list) or not payload:
        fail("根节点必须是非空数组")

    seen_ids: set[str] = set()
    for index, item in enumerate(payload):
        if not isinstance(item, dict):
            fail(f"第 {index + 1} 项不是对象")
        missing = REQUIRED_KEYS - item.keys()
        if missing:
            fail(f"第 {index + 1} 项缺少字段：{', '.join(sorted(missing))}")
        if not isinstance(item["id"], str) or not item["id"].strip():
            fail(f"第 {index + 1} 项的 id 必须是非空字符串")
        if item["id"] in seen_ids:
            fail(f"发现重复 id：{item['id']}")
        seen_ids.add(item["id"])
        if not isinstance(item["priority"], int) or item["priority"] < 1:
            fail(f"{item['id']} 的 priority 必须是 >= 1 的整数")
        if not isinstance(item["passes"], bool):
            fail(f"{item['id']} 的 passes 必须是布尔值")

    print(f"feature_list 校验通过：{path}")


if __name__ == "__main__":
    main()
