from __future__ import annotations

import json
import os
import sys
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

from pyiceberg.catalog import load_catalog
from pyiceberg.expressions import And, GreaterThanOrEqual, LessThan

from .ingest import TABLE


def _reader_catalog():
    token = Path(os.environ["AGENT_TRACES_READ_TOKEN_FILE"]).read_text().strip()
    return load_catalog(
        "agent-traces-reader",
        type="rest",
        uri=os.environ["AGENT_TRACES_CATALOG_URI"],
        warehouse=os.environ["AGENT_TRACES_WAREHOUSE"],
        token=token,
        **{"header.X-Iceberg-Access-Delegation": "vended-credentials"},
    )


def materialize_day(day: date, directory: Path, catalog=None) -> list[dict[str, object]]:
    catalog = catalog or _reader_catalog()
    start = datetime.combine(day, datetime.min.time(), UTC)
    end = start + timedelta(days=1)
    rows = catalog.load_table(TABLE).scan(
        row_filter=And(
            GreaterThanOrEqual("native_modified_at", start),
            LessThan("native_modified_at", end),
        ),
        selected_fields=(
            "source",
            "native_id",
            "native_modified_at",
            "observed_at",
            "trajectory_json",
            "normalization_status",
        ),
    ).to_arrow().to_pylist()
    latest: dict[tuple[str, str], dict[str, object]] = {}
    for row in rows:
        if row["normalization_status"] != "normalized" or row["trajectory_json"] is None:
            continue
        key = (row["source"], row["native_id"])
        current = latest.get(key)
        if current is None or (row["native_modified_at"], row["observed_at"]) > (
            current["native_modified_at"],
            current["observed_at"],
        ):
            latest[key] = row
    directory.mkdir(parents=True, exist_ok=True)
    manifest: list[dict[str, object]] = []
    for index, row in enumerate(sorted(latest.values(), key=lambda item: (item["source"], item["native_id"]))):
        payload = str(row["trajectory_json"]).encode()
        path = directory / f"{index:06d}.json"
        path.write_bytes(payload)
        manifest.append(
            {
                "bytes": len(payload),
                "client": row["source"],
                "format": "trajectory-v1",
                "modified": row["native_modified_at"].isoformat(),
                "path": str(path),
            }
        )
    return manifest


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: python -m agent_traces.query YYYY-MM-DD TMPDIR")
    manifest = materialize_day(date.fromisoformat(sys.argv[1]), Path(sys.argv[2]))
    print(json.dumps(manifest, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
