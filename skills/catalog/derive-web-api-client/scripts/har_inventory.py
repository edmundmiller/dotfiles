#!/usr/bin/env python3
"""Summarize likely API requests from a HAR without exposing captured secrets."""

from __future__ import annotations

import argparse
import json
import re
import stat
from collections import defaultdict
from pathlib import Path
from typing import Any
from urllib.parse import parse_qsl, urlsplit


STATIC_RESOURCE_TYPES = {
    "document",
    "font",
    "image",
    "media",
    "script",
    "stylesheet",
}
STATIC_MIME_PREFIXES = (
    "audio/",
    "font/",
    "image/",
    "text/css",
    "text/html",
    "video/",
)
SENSITIVE_HEADER_NAMES = {
    "authorization",
    "cookie",
    "proxy-authorization",
    "set-cookie",
    "x-api-key",
    "x-auth-token",
    "x-csrf-token",
    "x-xsrf-token",
}
UUID_SEGMENT = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    re.IGNORECASE,
)
LONG_NUMBER_SEGMENT = re.compile(r"^\d{5,}$")
TOKENISH_SEGMENT = re.compile(r"^[A-Za-z0-9_-]{24,}$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inventory likely API request shapes without emitting credential or payload values."
    )
    parser.add_argument("har", type=Path, help="Path to a HAR 1.2 JSON file")
    parser.add_argument("--host", help="Include only this exact hostname")
    parser.add_argument(
        "--include-assets",
        action="store_true",
        help="Include document and static asset requests",
    )
    return parser.parse_args()


def normalize_path(path: str) -> str:
    segments = []
    for segment in path.split("/"):
        if UUID_SEGMENT.fullmatch(segment):
            segment = "{uuid}"
        elif LONG_NUMBER_SEGMENT.fullmatch(segment):
            segment = "{id}"
        elif TOKENISH_SEGMENT.fullmatch(segment):
            segment = "{token}"
        segments.append(segment)
    return "/".join(segments) or "/"


def json_object(text: Any) -> dict[str, Any] | None:
    if not isinstance(text, str) or not text:
        return None
    try:
        value = json.loads(text)
    except (json.JSONDecodeError, TypeError):
        return None
    return value if isinstance(value, dict) else None


def header_names(request: dict[str, Any]) -> set[str]:
    names = set()
    for header in request.get("headers", []):
        if isinstance(header, dict) and isinstance(header.get("name"), str):
            names.add(header["name"].lower())
    return names


def is_likely_api(entry: dict[str, Any]) -> bool:
    resource_type = str(entry.get("_resourceType", "")).lower()
    content = entry.get("response", {}).get("content", {})
    mime_type = str(content.get("mimeType", "")).lower()
    request_mime = str(entry.get("request", {}).get("postData", {}).get("mimeType", "")).lower()
    if resource_type in {"fetch", "xhr"}:
        return True
    if resource_type in STATIC_RESOURCE_TYPES or mime_type.startswith(STATIC_MIME_PREFIXES):
        return False
    return "json" in mime_type or "json" in request_mime or "graphql" in mime_type


def build_inventory(har: dict[str, Any], host_filter: str | None, include_assets: bool) -> dict[str, Any]:
    entries = har.get("log", {}).get("entries", [])
    if not isinstance(entries, list):
        raise ValueError("HAR log.entries must be a list")

    groups: dict[tuple[str, str, str], dict[str, Any]] = defaultdict(
        lambda: {
            "count": 0,
            "statuses": set(),
            "mime_types": set(),
            "query_keys": set(),
            "request_header_names": set(),
            "auth_header_names": set(),
            "request_body_keys": set(),
            "response_body_keys": set(),
            "graphql_operations": set(),
        }
    )
    included = 0

    for raw_entry in entries:
        if not isinstance(raw_entry, dict):
            continue
        request = raw_entry.get("request", {})
        response = raw_entry.get("response", {})
        if not isinstance(request, dict) or not isinstance(response, dict):
            continue
        parsed = urlsplit(str(request.get("url", "")))
        if not parsed.hostname or (host_filter and parsed.hostname.lower() != host_filter.lower()):
            continue
        if not include_assets and not is_likely_api(raw_entry):
            continue

        method = str(request.get("method", "GET")).upper()
        path = normalize_path(parsed.path)
        group = groups[(method, parsed.hostname, path)]
        group["count"] += 1
        included += 1

        status = response.get("status")
        if isinstance(status, int):
            group["statuses"].add(status)
        mime_type = response.get("content", {}).get("mimeType")
        if isinstance(mime_type, str) and mime_type:
            group["mime_types"].add(mime_type.split(";", 1)[0].lower())
        group["query_keys"].update(key for key, _ in parse_qsl(parsed.query, keep_blank_values=True))

        names = header_names(request)
        group["request_header_names"].update(names)
        group["auth_header_names"].update(names & SENSITIVE_HEADER_NAMES)

        request_body = json_object(request.get("postData", {}).get("text"))
        if request_body:
            group["request_body_keys"].update(request_body)
            operation_name = request_body.get("operationName")
            if isinstance(operation_name, str) and operation_name:
                group["graphql_operations"].add(operation_name)

        response_body = json_object(response.get("content", {}).get("text"))
        if response_body:
            group["response_body_keys"].update(response_body)

    endpoints = []
    for (method, host, path), group in groups.items():
        endpoints.append(
            {
                "method": method,
                "host": host,
                "path": path,
                "count": group["count"],
                "statuses": sorted(group["statuses"]),
                "mime_types": sorted(group["mime_types"]),
                "query_keys": sorted(group["query_keys"]),
                "request_header_names": sorted(group["request_header_names"]),
                "auth_header_names": sorted(group["auth_header_names"]),
                "request_body_keys": sorted(group["request_body_keys"]),
                "response_body_keys": sorted(group["response_body_keys"]),
                "graphql_operations": sorted(group["graphql_operations"]),
            }
        )
    endpoints.sort(key=lambda item: (-item["count"], item["host"], item["path"], item["method"]))

    return {
        "entries_scanned": len(entries),
        "entries_included": included,
        "warning": (
            "Values are omitted except GraphQL operation names; paths and field names may still be sensitive."
        ),
        "endpoints": endpoints,
    }


def main() -> None:
    args = parse_args()
    try:
        mode = stat.S_IMODE(args.har.stat().st_mode)
        if mode & 0o077:
            raise ValueError(
                f"HAR permissions are {mode:04o}; run: chmod 600 {args.har}"
            )
        har = json.loads(args.har.read_text())
        if not isinstance(har, dict):
            raise ValueError("HAR root must be an object")
        inventory = build_inventory(har, args.host, args.include_assets)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        raise SystemExit(f"har_inventory: {error}") from error
    print(json.dumps(inventory, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
