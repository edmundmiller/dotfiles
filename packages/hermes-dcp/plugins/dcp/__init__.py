"""Hermes DCP context-engine plugin entrypoint."""

from __future__ import annotations

from typing import Any

from hermes_dcp.engine import DCPContextEngine


def register(ctx: Any) -> None:
    ctx.register_context_engine(DCPContextEngine())
