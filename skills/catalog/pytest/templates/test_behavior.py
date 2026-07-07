import json

import pytest

from package.module import parse_payload, write_record


def test_parse_payload_preserves_raw_on_malformed_json():
    assert parse_payload("{broken") == {"raw": "{broken"}


def test_write_record_writes_one_json_line(tmp_path):
    out = tmp_path / "records.jsonl"

    result = write_record(out, {"role": "user", "content": "hello"})

    assert result == out
    assert out.read_text().splitlines() == [json.dumps({"role": "user", "content": "hello"})]


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("yes", True),
        ("no", False),
    ],
)
def test_parse_payload_boolean_words(value, expected):
    assert parse_payload(value)["enabled"] is expected
