import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = SKILL_ROOT / "scripts/har_inventory.py"


class HarInventoryTest(unittest.TestCase):
    def run_inventory(self, har: dict, *args: str) -> dict:
        with tempfile.TemporaryDirectory() as temp_dir:
            har_path = Path(temp_dir) / "capture.har"
            har_path.write_text(json.dumps(har))
            har_path.chmod(0o600)
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(har_path), *args],
                check=True,
                capture_output=True,
                text=True,
            )
        return json.loads(result.stdout)

    def test_rejects_group_or_world_readable_har(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            har_path = Path(temp_dir) / "capture.har"
            har_path.write_text('{"log":{"entries":[]}}')
            har_path.chmod(0o644)

            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(har_path)],
                capture_output=True,
                text=True,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("chmod 600", result.stderr)

    def test_reports_request_shape_without_secret_values(self) -> None:
        secret = "never-print-this-token"
        har = {
            "log": {
                "entries": [
                    {
                        "_resourceType": "xhr",
                        "request": {
                            "method": "POST",
                            "url": f"https://food.example/api/stores/123456/search?q=pizza&token={secret}",
                            "headers": [
                                {"name": "Authorization", "value": f"Bearer {secret}"},
                                {"name": "Content-Type", "value": "application/json"},
                            ],
                            "postData": {
                                "mimeType": "application/json",
                                "text": json.dumps(
                                    {
                                        "operationName": "SearchStores",
                                        "variables": {"address": secret},
                                    }
                                ),
                            },
                        },
                        "response": {
                            "status": 200,
                            "content": {
                                "mimeType": "application/json",
                                "text": json.dumps({"data": {"stores": [secret]}}),
                            },
                        },
                    }
                ]
            }
        }

        output = self.run_inventory(har)

        serialized = json.dumps(output)
        self.assertNotIn(secret, serialized)
        self.assertEqual(output["entries_scanned"], 1)
        self.assertEqual(output["endpoints"][0]["path"], "/api/stores/{id}/search")
        self.assertEqual(output["endpoints"][0]["query_keys"], ["q", "token"])
        self.assertEqual(output["endpoints"][0]["request_body_keys"], ["operationName", "variables"])
        self.assertEqual(output["endpoints"][0]["response_body_keys"], ["data"])
        self.assertEqual(output["endpoints"][0]["graphql_operations"], ["SearchStores"])

    def test_groups_api_calls_and_excludes_static_assets(self) -> None:
        entries = []
        for status in (200, 304):
            entries.append(
                {
                    "_resourceType": "fetch",
                    "request": {
                        "method": "GET",
                        "url": "https://food.example/api/stores?page=1",
                        "headers": [],
                    },
                    "response": {
                        "status": status,
                        "content": {"mimeType": "application/json", "text": "{}"},
                    },
                }
            )
        entries.append(
            {
                "_resourceType": "image",
                "request": {
                    "method": "GET",
                    "url": "https://food.example/assets/logo.png",
                    "headers": [],
                },
                "response": {
                    "status": 200,
                    "content": {"mimeType": "image/png"},
                },
            }
        )

        output = self.run_inventory({"log": {"entries": entries}})

        self.assertEqual(output["entries_scanned"], 3)
        self.assertEqual(output["entries_included"], 2)
        self.assertEqual(len(output["endpoints"]), 1)
        self.assertEqual(output["endpoints"][0]["count"], 2)
        self.assertEqual(output["endpoints"][0]["statuses"], [200, 304])

    def test_filters_by_exact_host(self) -> None:
        def entry(host: str) -> dict:
            return {
                "_resourceType": "xhr",
                "request": {"method": "GET", "url": f"https://{host}/api/me", "headers": []},
                "response": {
                    "status": 200,
                    "content": {"mimeType": "application/json", "text": "{}"},
                },
            }

        output = self.run_inventory(
            {"log": {"entries": [entry("food.example"), entry("analytics.example")]}},
            "--host",
            "food.example",
        )

        self.assertEqual([item["host"] for item in output["endpoints"]], ["food.example"])


if __name__ == "__main__":
    unittest.main()
