"""Compile Hermes messages to VCC .min.txt — the compression summary.

VCC's .min.txt is a deterministic, structural summary that outperforms
LLM-generated summaries on AppWorld benchmarks (+1-4pp accuracy, 60%
fewer tokens).  No LLM call needed.  This module provides a single
function that takes Hermes messages and returns the .min.txt content.
"""

from __future__ import annotations

import logging
import tempfile
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


def compile_to_brief(messages: list[dict[str, Any]]) -> str | None:
    """Compile messages to VCC .min.txt — the structural summary.

    Converts Hermes OpenAI-format messages to VCC JSONL, runs VCC's
    compiler pipeline, and returns the .min.txt content directly.

    This is deterministic, instant, and free (no LLM call).

    Args:
        messages: Hermes OpenAI-format message list.

    Returns:
        The .min.txt content, or None on failure.
    """
    if not messages:
        return None

    try:
        from hermes_vcc.adapter import convert_conversation, records_to_jsonl
        from hermes_vcc.utils import import_vcc

        vcc = import_vcc()
        records = convert_conversation(messages)
        jsonl_text = records_to_jsonl(records)

        with tempfile.TemporaryDirectory(prefix="hermes_vcc_") as tmpdir:
            work_dir = Path(tmpdir)
            jsonl_path = work_dir / "input.jsonl"
            jsonl_path.write_text(jsonl_text, encoding="utf-8")

            vcc.compile_pass(
                str(jsonl_path), str(work_dir),
                truncate=128, truncate_user=256, quiet=True,
            )

            min_path = work_dir / "input.min.txt"
            if min_path.is_file():
                content = min_path.read_text(encoding="utf-8").strip()
                if content:
                    return content

    except Exception as exc:
        logger.warning("compile_to_brief failed: %s", exc)

    return None
