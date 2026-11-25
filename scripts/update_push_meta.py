#!/usr/bin/env python3
"""Capture summary of changes and Antigravity quota status into .github/last_push_meta.json."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys

FALLBACK_QUOTA = "Quota status unavailable in this environment"

ANSI_RE = re.compile(
    r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1B\\))"
)

RESET_TIMESTAMP_RE = re.compile(
    r"(?P<prefix>(?:(?:next\s+)?(?:resets?|refreshes?)(?:\s+(?:at|on|in|time))?\s*:?\s*))?"
    r"(?P<ts>\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:\s*UTC|Z|[+-]\d{2}:?\d{2})?)",
    re.IGNORECASE,
)


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def parse_utc_timestamp(ts_str: str) -> datetime | None:
    cleaned = ts_str.strip()
    if not cleaned:
        return None

    # Normalize trailing UTC / Z to +00:00 for broad Python compatibility
    if cleaned.upper().endswith("UTC"):
        cleaned = cleaned[:-3].strip() + "+00:00"
    elif cleaned.endswith(("Z", "z")):
        cleaned = cleaned[:-1] + "+00:00"

    # Normalize +HHMM / -HHMM offsets to +HH:MM / -HH:MM
    cleaned = re.sub(r"([+-]\d{2})(\d{2})$", r"\1:\2", cleaned)

    try:
        dt = datetime.fromisoformat(cleaned)
    except ValueError:
        return None

    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def format_countdown(delta_seconds: float) -> str:
    if delta_seconds <= 0:
        return "refreshes now"

    total_minutes = int(delta_seconds // 60)
    if total_minutes <= 0:
        return "refreshes in less than 1 minute"

    days, rem_minutes = divmod(total_minutes, 24 * 60)
    hours, minutes = divmod(rem_minutes, 60)

    parts: list[str] = []
    if days > 0:
        parts.append(f"{days} {'day' if days == 1 else 'days'}")
    if hours > 0:
        parts.append(f"{hours} {'hour' if hours == 1 else 'hours'}")
    if minutes > 0:
        parts.append(f"{minutes} {'minute' if minutes == 1 else 'minutes'}")

    if len(parts) == 1:
        joined = parts[0]
    elif len(parts) == 2:
        joined = f"{parts[0]} and {parts[1]}"
    else:
        joined = f"{parts[0]}, {parts[1]} and {parts[2]}"

    return f"refreshes in {joined}"


def format_quota_output(raw_output: str, now_utc: datetime | None = None) -> str:
    if now_utc is None:
        now_utc = datetime.now(timezone.utc)

    cleaned = strip_ansi(raw_output).replace("\r\n", "\n").replace("\r", "\n")
    lines = [line.rstrip() for line in cleaned.splitlines()]
    normalized = "\n".join(lines).strip()
    if not normalized:
        return FALLBACK_QUOTA

    def _replace_timestamp(match: re.Match[str]) -> str:
        prefix = match.group("prefix")
        ts_text = match.group("ts")
        parsed_dt = parse_utc_timestamp(ts_text)
        if parsed_dt is None:
            return match.group(0)

        delta_seconds = (parsed_dt - now_utc).total_seconds()
        if prefix is None and delta_seconds < -60:
            return match.group(0)

        return format_countdown(delta_seconds)

    formatted = RESET_TIMESTAMP_RE.sub(_replace_timestamp, normalized)
    return formatted


def fetch_quota_status(now_utc: datetime | None = None) -> str:
    try:
        proc = subprocess.run(
            ["agy", "-p", "/quota"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return FALLBACK_QUOTA

    if proc.returncode != 0:
        return FALLBACK_QUOTA

    raw_output = strip_ansi(proc.stdout or "").strip()
    if not raw_output:
        return FALLBACK_QUOTA

    lowered = raw_output.lower()
    auth_error_markers = (
        "not logged in",
        "not authenticated",
        "authentication required",
        "please sign in",
        "login required",
        "unauthorized",
    )
    if "%" not in raw_output and any(marker in lowered for marker in auth_error_markers):
        return FALLBACK_QUOTA

    return format_quota_output(raw_output, now_utc=now_utc)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Update .github/last_push_meta.json with push summary and Antigravity quota."
    )
    parser.add_argument(
        "--summary",
        required=True,
        help="Concise bulleted summary of changes for this commit/push.",
    )
    args = parser.parse_args()

    now_utc = datetime.now(timezone.utc)
    quota_status = fetch_quota_status(now_utc=now_utc)

    repo_root = Path(__file__).resolve().parent.parent
    meta_path = repo_root / ".github" / "last_push_meta.json"
    meta_path.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "summary": args.summary.strip(),
        "quota": quota_status,
        "updated_at_utc": now_utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    meta_path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Updated {meta_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
