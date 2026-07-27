from __future__ import annotations

import fcntl
import hashlib
import json
import os
import sys
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Iterable, Iterator

import pyarrow as pa
from pyiceberg.catalog import Catalog, load_catalog
from pyiceberg.exceptions import NamespaceAlreadyExistsError, NoSuchTableError
from pyiceberg.io.pyarrow import schema_to_pyarrow

from .schema import ICEBERG_SCHEMA, PARTITION_SPEC
from .sources import Candidate, discover_candidates

TABLE = "agent_traces.sessions"


@dataclass(frozen=True)
class IngestResult:
    discovered: int
    unchanged: int
    inserted: int
    failed: int

    def as_dict(self) -> dict[str, int]:
        return {
            "discovered": self.discovered,
            "failed": self.failed,
            "inserted": self.inserted,
            "unchanged": self.unchanged,
        }


@contextmanager
def writer_lock(path: Path) -> Iterator[None]:
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = path.open("a")
    try:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError("agent-traces ingestion is already running") from error
        yield
    finally:
        handle.close()


def _ensure_table(catalog: Catalog):
    try:
        catalog.create_namespace("agent_traces")
    except NamespaceAlreadyExistsError:
        pass
    try:
        return catalog.load_table(TABLE)
    except NoSuchTableError:
        return catalog.create_table(TABLE, schema=ICEBERG_SCHEMA, partition_spec=PARTITION_SPEC)


def _canonical_json(value: object) -> str:
    # ponytail: ascii-escape lone surrogates instead of custom tree walk
    return json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True, allow_nan=False)


def _normalize(candidate: Candidate, native: bytes) -> tuple[list[object], list[object]]:
    result = candidate.normalize(native)
    if isinstance(result, tuple):
        records, diagnostics = result
    else:
        records, diagnostics = result, []
    if not isinstance(records, list) or not records:
        raise ValueError("normalizer returned no trajectory records")
    return records, diagnostics if isinstance(diagnostics, list) else []


def _flush_rows(table, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    arrow = pa.Table.from_pylist(rows, schema=schema_to_pyarrow(ICEBERG_SCHEMA))
    # ponytail: append is enough; immutable keys + local hash set prevent dupes within a run
    table.append(arrow)
    rows.clear()


def ingest_candidates(
    catalog: Catalog,
    candidates: Iterable[Candidate],
    observed_at: datetime | None = None,
    batch_size: int = 200,
) -> IngestResult:
    table = _ensure_table(catalog)
    candidates = list(candidates)
    observed_at = (observed_at or datetime.now(UTC)).astimezone(UTC)
    existing_rows = table.scan(
        selected_fields=("source", "native_id", "version_hash", "native_size", "native_modified_at")
    ).to_arrow().to_pylist()
    metadata = {
        (row["source"], row["native_id"], row["native_size"], row["native_modified_at"]): row["version_hash"]
        for row in existing_rows
    }
    hashes = {(row["source"], row["native_id"], row["version_hash"]) for row in existing_rows}
    rows: list[dict[str, object]] = []
    unchanged = 0
    failed = 0
    inserted = 0

    for candidate in candidates:
        cheap_key = (candidate.source, candidate.native_id, candidate.native_size, candidate.native_modified_at)
        if cheap_key in metadata:
            unchanged += 1
            continue
        native = candidate.read()
        version_hash = hashlib.sha256(native).hexdigest()
        if (candidate.source, candidate.native_id, version_hash) in hashes:
            unchanged += 1
            continue
        try:
            records, diagnostics = _normalize(candidate, native)
            status = "normalized"
            trajectory_json = _canonical_json(records)
        except Exception as error:
            records = []
            diagnostics = [{"message": str(error), "type": type(error).__name__}]
            status = "raw_only"
            trajectory_json = None
            failed += 1
        rows.append(
            {
                "source": candidate.source,
                "native_id": candidate.native_id,
                "version_hash": version_hash,
                "observed_at": observed_at,
                "native_modified_at": candidate.native_modified_at.astimezone(UTC),
                "started_at": candidate.started_at,
                "updated_at": candidate.updated_at,
                "native_size": len(native),
                "native_format": candidate.native_format,
                "native_locator": candidate.native_locator,
                "title": candidate.title,
                "cwd": candidate.cwd,
                "model": candidate.model,
                "normalization_status": status,
                "record_count": len(records),
                "diagnostics_json": _canonical_json(diagnostics),
                "trajectory_json": trajectory_json,
                "native_bytes": native,
            }
        )
        inserted += 1
        hashes.add((candidate.source, candidate.native_id, version_hash))
        metadata[cheap_key] = version_hash
        if len(rows) >= batch_size:
            _flush_rows(table, rows)
            print(
                _canonical_json(
                    {
                        "batch": True,
                        "discovered": len(candidates),
                        "failed": failed,
                        "inserted": inserted,
                        "unchanged": unchanged,
                    }
                ),
                flush=True,
            )

    _flush_rows(table, rows)
    return IngestResult(len(candidates), unchanged, inserted, failed)


def _catalog_from_env() -> Catalog:
    token_path = Path(os.environ["AGENT_TRACES_WRITE_TOKEN_FILE"])
    return load_catalog(
        "agent-traces",
        type="rest",
        uri=os.environ["AGENT_TRACES_CATALOG_URI"],
        warehouse=os.environ["AGENT_TRACES_WAREHOUSE"],
        token=token_path.read_text().strip(),
        **{"header.X-Iceberg-Access-Delegation": "vended-credentials"},
    )


def _since_from_env() -> datetime | None:
    value = os.environ.get("AGENT_TRACES_SINCE")
    if not value:
        return None
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def main() -> int:
    lock_path = Path("~/.local/state/agent-traces/ingest.lock").expanduser()
    try:
        with writer_lock(lock_path):
            result = ingest_candidates(_catalog_from_env(), discover_candidates(_since_from_env()))
        print(_canonical_json({"ok": result.failed == 0, **result.as_dict()}))
        return 1 if result.failed else 0
    except Exception as error:
        print(_canonical_json({"error": str(error), "ok": False}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
