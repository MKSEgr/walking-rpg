#!/usr/bin/env python3
"""Fail closed on ambiguous GitHub issue-closing references in PR metadata."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


MAX_EVENT_BYTES = 8 * 1024 * 1024
MAX_TITLE_CHARS = 512
MAX_BODY_CHARS = 262_144
ISSUE = r"[1-9][0-9]{0,8}"
OWNER = r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})"
REPOSITORY = r"[A-Za-z0-9_.-]+"
REFERENCE = (
    rf"(?:#{ISSUE}|{OWNER}/{REPOSITORY}#{ISSUE}|"
    rf"https://github\.com/{OWNER}/{REPOSITORY}/issues/{ISSUE})"
)
CLOSING_REFERENCE = re.compile(
    rf"\b(?:close(?:s|d)?|fix(?:es|ed)?|resolve(?:s|d)?)"
    rf"(?:\s*:\s*|\s+){REFERENCE}",
    re.IGNORECASE,
)
CANONICAL_REFERENCE = re.compile(rf"Closes #({ISSUE})")
FENCE = re.compile(r"^[ \t]{0,3}(`{3,}|~{3,})")


class PullRequestMetadataError(ValueError):
    pass


def _unique(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise PullRequestMetadataError(f"event: duplicate JSON key {key!r}")
        result[key] = value
    return result


def _matches(value: str) -> list[re.Match[str]]:
    return list(CLOSING_REFERENCE.finditer(value))


def validate_metadata(title: Any, body: Any) -> tuple[int, ...]:
    if (
        not isinstance(title, str)
        or not title.strip()
        or len(title) > MAX_TITLE_CHARS
    ):
        raise PullRequestMetadataError("title: must be a non-empty bounded string")
    if body is None:
        body = ""
    if not isinstance(body, str) or len(body) > MAX_BODY_CHARS:
        raise PullRequestMetadataError("body: must be null or a bounded string")
    if _matches(title):
        raise PullRequestMetadataError(
            "title: issue-closing references are allowed only as canonical body lines"
        )

    accepted: list[int] = []
    fence: tuple[str, int] | None = None
    for line_number, line in enumerate(body.splitlines(), start=1):
        matches = _matches(line)
        canonical = CANONICAL_REFERENCE.fullmatch(line)
        if matches:
            if fence is not None or canonical is None or len(matches) != 1:
                raise PullRequestMetadataError(
                    f"body line {line_number}: ambiguous issue-closing reference; "
                    "use one exact standalone 'Closes #N' line only for completed acceptance"
                )
            issue = int(canonical.group(1))
            if issue in accepted:
                raise PullRequestMetadataError(
                    f"body line {line_number}: duplicate completion reference for issue #{issue}"
                )
            accepted.append(issue)

        marker = FENCE.match(line)
        if marker:
            token = marker.group(1)
            if fence is None:
                fence = token[0], len(token)
            elif token[0] == fence[0] and len(token) >= fence[1]:
                fence = None
    return tuple(accepted)


def validate_event(path: Path) -> tuple[int, ...]:
    raw = path.read_bytes()
    if not raw or len(raw) > MAX_EVENT_BYTES:
        raise PullRequestMetadataError("event: file must be non-empty and bounded")
    event = json.loads(raw, object_pairs_hook=_unique)
    if not isinstance(event, dict):
        raise PullRequestMetadataError("event: root must be an object")
    pull_request = event.get("pull_request")
    if not isinstance(pull_request, dict):
        raise PullRequestMetadataError("event.pull_request: object is required")
    number = pull_request.get("number", event.get("number"))
    if type(number) is not int or number < 1:
        raise PullRequestMetadataError(
            "event.pull_request.number: positive integer is required"
        )
    return validate_metadata(pull_request.get("title"), pull_request.get("body"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--event", type=Path, help="GitHub pull_request event JSON")
    source.add_argument("--body-file", type=Path, help="local PR body text")
    parser.add_argument("--title", default="Local pull request")
    args = parser.parse_args(argv)
    try:
        if args.event:
            issues = validate_event(args.event)
            subject = args.event
        else:
            issues = validate_metadata(
                args.title,
                args.body_file.read_text(encoding="utf-8"),
            )
            subject = args.body_file
    except (OSError, UnicodeError, json.JSONDecodeError, PullRequestMetadataError) as error:
        print(f"Pull request metadata invalid: {error}", file=sys.stderr)
        return 1
    rendered = ", ".join(f"#{issue}" for issue in issues) or "none"
    print(f"Pull request closing references valid: {subject} ({rendered})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
