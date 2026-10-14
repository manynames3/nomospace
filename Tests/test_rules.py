#!/usr/bin/env python3
"""Validate cleanup metadata in CI without making any destructive changes."""
import json
from pathlib import Path

rules = json.loads(Path("Sources/nomospace/Resources/Rules/storage-rules.json").read_text())
ids, paths = set(), set()
risks = {"safe", "usuallySafe", "review", "protected"}
required = {"id", "title", "relativePath", "category", "risk", "explanation", "sideEffect", "source", "minimumBytes"}
for item in rules:
    assert required <= item.keys(), f"Missing keys: {item}"
    assert item["id"] not in ids, f"Duplicate ID {item['id']}"
    assert item["relativePath"] not in paths, f"Duplicate path {item['relativePath']}"
    assert item["risk"] in risks, f"Unknown risk: {item}"
    assert item["relativePath"] and not item["relativePath"].startswith("/")
    assert not any(p in ("", ".", "..") for p in item["relativePath"].split("/"))
    assert isinstance(item["minimumBytes"], int) and item["minimumBytes"] >= 0
    assert all(item[k].strip() for k in ("title", "explanation", "sideEffect", "source"))
    ids.add(item["id"])
    paths.add(item["relativePath"])

by_id = {item["id"]: item for item in rules}
for sensitive in ("claude-vm-bundles", "xcode-archives", "docker-container-state", "orbstack-machine-state", "codex-local-state"):
    assert by_id[sensitive]["risk"] == "protected", f"Unsafe default: {sensitive}"
assert by_id["core-simulator-user-devices"]["risk"] != "safe"
print(f"Rule validation passed: {len(rules)} unique and structurally safe rules")
