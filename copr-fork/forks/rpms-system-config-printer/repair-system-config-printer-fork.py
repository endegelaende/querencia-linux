#!/usr/bin/env python3
"""
Repair the `rpms-system-config-printer` fork so it is based on the full Fedora f43
spec with only the minimal EL10-enabling delta applied.

What this script does
---------------------
1. Reads an upstream Fedora `system-config-printer.spec`
2. Applies the Querencia EL10 patch in a conservative way:
   - adds `.querencia1` to the Release tag
   - removes the `%if 0%{?rhel} > 8` GUI-deletion block in `%install`
   - removes the `%if 0%{?rhel} <= 8 || 0%{?fedora}` guards around:
       * `%package applet` / `%description applet`
       * `%files applet`
       * `%files`
       * `%post`
   - prepends short explanatory comments near the modified sections
   - prepends a new changelog entry
3. Writes the repaired spec to stdout or a target file

It is intentionally text-based and opinionated toward the current Fedora f43 spec
shape discussed in Querencia. If upstream changes drastically, the script should
fail loudly rather than silently generate a wrong spec.

Typical usage
-------------
python repair-system-config-printer-fork.py ^
  --input C:\\path\\to\\upstream\\system-config-printer.spec ^
  --output C:\\path\\to\\patched\\system-config-printer.spec

Then:
  - replace the spec in the git checkout
  - commit
  - push/force-push the `f43-el10` branch as needed
"""

from __future__ import annotations

import argparse
import datetime as _dt
import re
import sys
from pathlib import Path

APPLET_GUARD = "%if 0%{?rhel} <= 8 || 0%{?fedora}"
GUI_DELETE_GUARD = "%if 0%{?rhel} > 8"
CHANGELOG_MARKER = "%changelog"


class PatchError(RuntimeError):
    pass


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8-sig")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="\n")


def ensure_release_suffix(text: str) -> str:
    pattern = re.compile(r"^Release:\s+(.+)$", re.MULTILINE)
    match = pattern.search(text)
    if not match:
        raise PatchError("Could not find Release line in spec.")

    old = match.group(1).strip()
    if ".querencia1" in old:
        return text

    if old.endswith("%{?dist}"):
        new = old[:-8] + "%{?dist}.querencia1"
    else:
        new = old + ".querencia1"

    return text[: match.start(1)] + new + text[match.end(1) :]


def remove_gui_delete_block(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []

    i = 0
    removed = False
    inserted_comment = False

    while i < len(lines):
        line = lines[i]

        if line.strip() == GUI_DELETE_GUARD:
            j = i + 1
            while j < len(lines) and lines[j].strip() != "%endif":
                j += 1
            if j >= len(lines):
                raise PatchError("Found GUI delete guard but no matching %endif.")

            if not inserted_comment:
                out.append(
                    "# Querencia Linux: removed the RHEL>8 GUI deletion block so EL10 keeps"
                )
                out.append(
                    "# the main GUI, applet, desktop files, icons, troubleshooter and UI assets."
                )
                inserted_comment = True

            removed = True
            i = j + 1
            continue

        out.append(line)
        i += 1

    if not removed:
        raise PatchError("Did not find the RHEL>8 GUI deletion block to remove.")

    return "\n".join(out) + "\n"


def _find_guard_spans(lines: list[str]) -> list[tuple[int, int]]:
    spans: list[tuple[int, int]] = []
    i = 0
    while i < len(lines):
        if lines[i].strip() == APPLET_GUARD:
            j = i + 1
            while j < len(lines) and lines[j].strip() != "%endif":
                j += 1
            if j >= len(lines):
                raise PatchError(
                    f"Found guard '{APPLET_GUARD}' without matching %endif."
                )
            spans.append((i, j))
            i = j + 1
        else:
            i += 1
    return spans


def _span_contains(lines: list[str], start: int, end: int, needle: str) -> bool:
    return any(needle in lines[k] for k in range(start, end + 1))


def remove_rhel_guards(text: str) -> str:
    lines = text.splitlines()
    spans = _find_guard_spans(lines)

    if len(spans) < 3:
        raise PatchError(
            f"Expected at least 3 guarded blocks using '{APPLET_GUARD}', found {len(spans)}."
        )

    classified: dict[str, tuple[int, int]] = {}

    for start, end in spans:
        if _span_contains(lines, start, end, "%package applet"):
            classified["package_applet"] = (start, end)
        elif _span_contains(lines, start, end, "%files applet"):
            classified["files_applet"] = (start, end)
        elif _span_contains(lines, start, end, "%files") and not _span_contains(
            lines, start, end, "%files applet"
        ):
            classified["files_main"] = (start, end)

    if "package_applet" not in classified:
        raise PatchError("Could not identify guarded `%package applet` block.")
    if "files_applet" not in classified:
        raise PatchError("Could not identify guarded `%files applet` block.")
    if "files_main" not in classified:
        raise PatchError("Could not identify guarded main `%files` block.")

    to_strip = {
        classified["package_applet"][0],
        classified["package_applet"][1],
        classified["files_applet"][0],
        classified["files_applet"][1],
        classified["files_main"][0],
        classified["files_main"][1],
    }

    out: list[str] = []
    for idx, line in enumerate(lines):
        if idx == classified["package_applet"][0]:
            out.append("# Querencia Linux: always build the applet subpackage on EL10")
        elif idx == classified["files_applet"][0]:
            out.append("# Querencia Linux: always ship applet files on EL10")
        elif idx == classified["files_main"][0]:
            out.append("# Querencia Linux: always ship the main GUI package on EL10")

        if idx in to_strip:
            continue
        out.append(line)

    return "\n".join(out) + "\n"


def ensure_post_inside_main_files_block(text: str) -> str:
    # Sanity check only. In the current upstream structure, after removing the
    # main `%files` guard, `%post` should still remain intact and present.
    if "\n%post\n" not in text:
        raise PatchError("Expected `%post` section is missing after patching.")
    return text


def add_changelog_entry(text: str) -> str:
    idx = text.find(CHANGELOG_MARKER)
    if idx == -1:
        raise PatchError("Could not find %changelog marker.")

    today = _dt.datetime.utcnow().strftime("%a %b %d %Y")
    entry = (
        f"%changelog\n"
        f"* {today} Querencia Linux <querencia@endegelaende.github.io> - 1.5.18-16.querencia1\n"
        f"- Enable full GUI build on EL10 by removing RHEL-only GUI stripping conditionals\n"
        f"- Always build and ship the applet subpackage on EL10\n"
        f"\n"
    )

    # Replace the first %changelog marker with marker + new entry.
    return text[:idx] + entry + text[idx + len(CHANGELOG_MARKER) + 1 :]


def patch_spec(text: str) -> str:
    original = text

    if "%package applet" not in text:
        raise PatchError(
            "Input spec does not look like system-config-printer f43 spec."
        )

    text = ensure_release_suffix(text)
    text = remove_gui_delete_block(text)
    text = remove_rhel_guards(text)
    text = ensure_post_inside_main_files_block(text)
    text = add_changelog_entry(text)

    if text == original:
        raise PatchError("No changes were applied.")
    return text


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Repair system-config-printer fork spec from full Fedora f43 spec."
    )
    parser.add_argument(
        "--input",
        required=True,
        help="Path to the upstream Fedora f43 system-config-printer.spec",
    )
    parser.add_argument(
        "--output",
        help="Optional output path. If omitted, writes patched spec to stdout.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"ERROR: input file not found: {input_path}", file=sys.stderr)
        return 2

    try:
        source = read_text(input_path)
        patched = patch_spec(source)
    except PatchError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if args.output:
        output_path = Path(args.output)
        write_text(output_path, patched)
    else:
        sys.stdout.write(patched)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
