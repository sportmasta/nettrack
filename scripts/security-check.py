#!/usr/bin/env python3
"""Refuse tracked device dumps and obvious hardcoded secrets."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = ["12.09.backup", "12.09.rsc"]
SECRET_ASSIGN = re.compile(
    r"(password|secret|pre-shared-key|passphrase)=(?!REDACTED)[^\s\"']+",
    re.I,
)


def tracked_files() -> list[str] | None:
    try:
        out = subprocess.check_output(
            ["git", "ls-files"],
            cwd=ROOT,
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return [line.strip() for line in out.splitlines() if line.strip()]
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def iter_source_files() -> list[str]:
    skip = {".venv", "node_modules", ".git", "__pycache__", "frontend/dist"}
    files = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT).as_posix()
        if any(part in skip for part in rel.split("/")):
            continue
        files.append(rel)
    return files


def main() -> int:
    tracked = tracked_files()
    files = tracked if tracked is not None else iter_source_files()
    fail = 0
    if tracked is not None:
        for name in FORBIDDEN:
            if name in tracked:
                print(f"FAIL: {name} must not be tracked")
                fail = 1
    inspect_ext = {".py", ".jsx", ".js", ".yml", ".yaml", ".env"}
    skip_prefix = ("config/", "backend/tests/fixtures/")
    skip_names = {"docker-compose.yml", ".env.example"}
    for rel in files:
        path = ROOT / rel
        if path.suffix not in inspect_ext:
            continue
        if rel in skip_names or rel.startswith(skip_prefix):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if SECRET_ASSIGN.search(text):
            print(f"FAIL: possible hardcoded secret in {rel}")
            fail = 1
    if fail == 0:
        print("OK: security-check passed")
    return fail


if __name__ == "__main__":
    sys.exit(main())
