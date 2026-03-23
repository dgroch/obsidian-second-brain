#!/usr/bin/env python3
"""
Task Tidy — full implementation of the task-management skill protocol.

Rules:
  1. Active tasks sorted per section: priority (P0 > P1 > P2), then due date (earliest first)
  2. Completed tasks ([x]/[X]) moved to ## Completed section at bottom
  3. Completed tasks without [DONE: YYYY-MM-DD] get today's date stamped
  4. Active tasks without [PX] tag default to P2
  5. Inline display-only annotations (⚠️ OVERDUE, bold notes) stripped
  6. Format: - [ ] [DUE: YYYY-MM-DD] [PX] Description
  7. Completed section sorted newest first by DONE date

Runs before git/obsidian sync to keep the file clean.
"""

import re
import sys
from datetime import date
from pathlib import Path

TASKS_PATH = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/data/.openclaw/workspace/secondbrain/Tasks.md")
TODAY = date.today().strftime("%Y-%m-%d")
FAR_FUTURE = "9999-99-99"


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def parse_priority(line: str) -> int:
    m = re.search(r"\[P([012])\]", line)
    return int(m.group(1)) if m else 2


def parse_due(line: str) -> str:
    m = re.search(r"\[DUE:\s*(\d{4}-\d{2}-\d{2})\]", line)
    return m.group(1) if m else FAR_FUTURE


def parse_done(line: str) -> str:
    m = re.search(r"\[DONE:\s*(\d{4}-\d{2}-\d{2})\]", line)
    return m.group(1) if m else "0000-00-00"


def strip_annotations(line: str) -> str:
    """Remove display-only annotations that don't belong in the source file."""
    line = re.sub(r"\s*⚠️\s*\*\*OVERDUE[^*]*\*\*", "", line)
    line = re.sub(r"\s*—\s*\*\*Due[^*]*\*\*", "", line)
    line = re.sub(r"\s*\*\*OVERDUE[^*]*\*\*", "", line)
    return re.sub(r"  +", " ", line).rstrip()


def is_open_task(line: str) -> bool:
    return bool(re.match(r"^\s*- \[ \]", line))


def is_completed_task(line: str) -> bool:
    return bool(re.match(r"^\s*- \[[xX]\]", line))


def stamp_done(line: str) -> str:
    """Add [DONE: today] to a completed task that doesn't have one."""
    if re.search(r"\[DONE:\s*\d{4}-\d{2}-\d{2}\]", line):
        return line
    # Insert after the checkbox
    return re.sub(r"(- \[[xX]\]\s*)", rf"\1[DONE: {TODAY}] ", line, count=1)


def sort_key_active(line: str):
    return (parse_priority(line), parse_due(line), line.lower())


def sort_key_done(line: str):
    return parse_done(line)


# ---------------------------------------------------------------------------
# Parser — reads the file into structured blocks
# ---------------------------------------------------------------------------

class Block:
    """Represents a section (### heading + its tasks + trailing non-task lines)."""
    def __init__(self, heading: str = ""):
        self.heading = heading        # e.g. "### Fig & Bloom"
        self.active: list[str] = []
        self.other: list[str] = []    # non-task lines that belong to this section


def parse_file(text: str):
    """
    Returns:
        title_block  — lines before the first ### section (e.g. # Tasks)
        sections     — list of Block objects
        completed    — list of completed task lines (from all sections + Completed section)
    """
    lines = text.split("\n")
    title_block: list[str] = []
    sections: list[Block] = []
    completed: list[str] = []
    current: Block | None = None
    in_completed_section = False

    for line in lines:
        # ## Completed section heading — switch mode
        if re.match(r"^##\s+Completed\s*$", line, re.IGNORECASE):
            if current is not None:
                sections.append(current)
                current = None
            in_completed_section = True
            continue

        # Any ## heading that isn't Completed and isn't a ### section
        if re.match(r"^##[^#]", line) and not re.match(r"^##\s+Completed", line, re.IGNORECASE):
            if current is not None:
                sections.append(current)
            current = Block(line)
            in_completed_section = False
            continue

        # ### project heading
        if re.match(r"^###\s+", line):
            if current is not None:
                sections.append(current)
            current = Block(line)
            in_completed_section = False
            continue

        # Completed task
        if is_completed_task(line):
            completed.append(stamp_done(strip_annotations(line)))
            continue

        # Open task
        if is_open_task(line):
            clean = strip_annotations(line)
            if current is not None:
                current.active.append(clean)
            else:
                # Task before any section heading — put in a default section
                current = Block("### General")
                current.active.append(clean)
            continue

        # Everything else (blank lines, non-task text)
        if in_completed_section:
            continue  # discard — we rebuild Completed ourselves
        if current is None:
            title_block.append(line)
        else:
            current.other.append(line)

    if current is not None:
        sections.append(current)

    return title_block, sections, completed


# ---------------------------------------------------------------------------
# Renderer
# ---------------------------------------------------------------------------

def render(title_block: list[str], sections, completed: list[str]) -> str:
    out: list[str] = []

    # Title block (e.g. # Tasks + any intro lines)
    for line in title_block:
        out.append(line)

    # Ensure exactly one blank line after title block
    while out and out[-1].strip() == "":
        out.pop()
    out.append("")

    # Active sections
    for block in sections:
        if not block.active and not block.other:
            continue  # skip empty sections

        out.append(block.heading)

        # Sort active tasks
        block.active.sort(key=sort_key_active)
        for t in block.active:
            out.append(t)

        # Trailing non-task lines (notes, etc.) within section
        for l in block.other:
            if l.strip():  # skip blank lines within section trailing
                out.append(l)

        out.append("")

    # Completed section
    if completed:
        completed.sort(key=sort_key_done, reverse=True)
        out.append("## Completed")
        for c in completed:
            out.append(c)
        out.append("")

    return "\n".join(out)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if not TASKS_PATH.exists():
        print(f"Tasks file not found: {TASKS_PATH}", file=sys.stderr)
        sys.exit(0)

    original = TASKS_PATH.read_text(encoding="utf-8")

    try:
        title_block, sections, completed = parse_file(original)
        tidied = render(title_block, sections, completed)
    except Exception as e:
        print(f"task-tidy ERROR: {e}", file=sys.stderr)
        sys.exit(0)  # Fail soft — don't break the bridge on a parse error

    if tidied.rstrip() != original.rstrip():
        TASKS_PATH.write_text(tidied, encoding="utf-8")
        print(f"Tidied {TASKS_PATH}")
    else:
        print(f"No changes needed for {TASKS_PATH}")
