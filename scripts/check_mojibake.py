from __future__ import annotations

import argparse
import sys
from pathlib import Path


SUSPICIOUS_FRAGMENTS = (
    "姝ｅ湪鍔犺浇",
    "鐗涚墰",
    "绔炰环",
    "鎸夋棫",
    "宸︿晶",
    "鍙充晶",
    "瀵煎嚭",
    "澶嶅埗",
    "鑷姩",
    "鎾悎",
    "鏆傛棤",
    "褰撳墠",
    "鏈€杩",
    "鏄ㄦ棩",
    "鍒嗘瀽",
    "鎻愮ず璇",
    "鍙戦€",
    "绯荤粺鎻愮ず",
    "寰呭彂閫",
    "宸插彂閫",
    "鍏抽棴",
    "鏌ョ湅",
    "闂瓵I",
    "杞藉叆璁板綍",
    "鍚敤",
    "寮€鏈",
)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scan Flutter source for common mojibake fragments.",
    )
    parser.add_argument(
        "--project-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Flutter project directory. Defaults to the parent of this script.",
    )
    parser.add_argument(
        "--roots",
        nargs="*",
        default=("lib", "test"),
        help="Relative roots under the project directory to scan.",
    )
    return parser.parse_args()


def _strip_comments(line: str, in_block_comment: bool) -> tuple[str, bool]:
    output: list[str] = []
    index = 0
    in_single_quote = False
    in_double_quote = False

    while index < len(line):
        current = line[index]
        nxt = line[index + 1] if index + 1 < len(line) else ""

        if in_block_comment:
            if current == "*" and nxt == "/":
                in_block_comment = False
                index += 2
            else:
                index += 1
            continue

        if not in_single_quote and not in_double_quote:
            if current == "/" and nxt == "/":
                break
            if current == "/" and nxt == "*":
                in_block_comment = True
                index += 2
                continue

        output.append(current)

        escaped = index > 0 and line[index - 1] == "\\"
        if current == "'" and not in_double_quote and not escaped:
            in_single_quote = not in_single_quote
        elif current == '"' and not in_single_quote and not escaped:
            in_double_quote = not in_double_quote

        index += 1

    return "".join(output), in_block_comment


def _scan_file(path: Path) -> list[tuple[int, str, str]]:
    findings: list[tuple[int, str, str]] = []
    in_block_comment = False

    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        scan_line, in_block_comment = _strip_comments(raw_line, in_block_comment)
        for fragment in SUSPICIOUS_FRAGMENTS:
            if fragment in scan_line:
                findings.append((line_number, fragment, raw_line.strip()))
                break

    return findings


def main() -> int:
    args = _parse_args()
    project_dir = args.project_dir.resolve()

    candidate_files: list[Path] = []
    for relative_root in args.roots:
        root = (project_dir / relative_root).resolve()
        if not root.exists():
            continue
        candidate_files.extend(sorted(root.rglob("*.dart")))

    findings: list[tuple[Path, int, str, str]] = []
    for path in candidate_files:
        for line_number, fragment, line in _scan_file(path):
            findings.append((path, line_number, fragment, line))

    if findings:
        print("Detected suspicious mojibake fragments:", file=sys.stderr)
        for path, line_number, fragment, line in findings:
            relative_path = path.relative_to(project_dir)
            print(
                f"  {relative_path}:{line_number}: matched `{fragment}` -> {line}",
                file=sys.stderr,
            )
        return 1

    scanned_roots = ", ".join(args.roots)
    print(f"No suspicious mojibake fragments found under: {scanned_roots}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
