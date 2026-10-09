"""The permission policy is authored as JSONC but consumed as strict JSON.

@gotgenes/pi-permission-system loads it with
``JSON.parse(stripJsonComments(raw))``. Comments are stripped; trailing commas
are not. Linking the raw .jsonc made every load fail closed to ``{}`` -- no
rule in effect -- and the extension's ``save()`` then wrote
``{...existing.config, debugLog, permissionReviewLog, yoloMode}`` over the
Home Manager symlink, leaving a four-key stub.
"""

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POLICY = ROOT / "config/pi/pi-permission-system.jsonc"


def strip_json_comments(text: str) -> str:
    """Mirror strip-json-comments: drop // and /* */ outside string literals."""
    out = []
    i = 0
    in_string = escaped = line_comment = block_comment = False
    while i < len(text):
        char, nxt = text[i], text[i + 1 : i + 2]
        if line_comment:
            if char == "\n":
                line_comment = False
                out.append(char)
            i += 1
        elif block_comment:
            if char == "*" and nxt == "/":
                block_comment = False
                i += 2
            else:
                i += 1
        elif in_string:
            out.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            i += 1
        elif char == '"':
            in_string = True
            out.append(char)
            i += 1
        elif char == "/" and nxt == "/":
            line_comment = True
            i += 2
        elif char == "/" and nxt == "*":
            block_comment = True
            i += 2
        else:
            out.append(char)
            i += 1
    return "".join(out)


def strip_trailing_commas(text: str) -> str:
    """Drop `,` that sits before a closing brace/bracket, outside strings."""
    out = []
    in_string = escaped = False
    for index, char in enumerate(text):
        if in_string:
            out.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
            out.append(char)
            continue
        if char == ",":
            rest = text[index + 1 :].lstrip()
            if rest[:1] in ("}", "]"):
                continue
        out.append(char)
    return "".join(out)


class PiPermissionSystemConfigTests(unittest.TestCase):
    def test_raw_policy_is_unreadable_by_the_extensions_parser(self) -> None:
        """Comments alone are not enough: the file also has trailing commas."""
        comments_only = strip_json_comments(POLICY.read_text())

        with self.assertRaises(json.JSONDecodeError):
            json.loads(comments_only)

    def test_policy_parses_once_trailing_commas_go_too(self) -> None:
        policy = json.loads(strip_trailing_commas(strip_json_comments(POLICY.read_text())))

        self.assertGreater(len(policy["permission"]["bash"]), 50)
        self.assertEqual(policy["permission"]["path"]["~/.ssh/*"], "deny")

    def test_modules_materialize_parsed_json_not_the_raw_jsonc(self) -> None:
        """A `.source` link would hand the extension trailing commas."""
        for module in (
            ROOT / "modules/agents/pi/lib/_home-files.nix",
            ROOT / "modules/agents/omp/default.nix",
        ):
            with self.subTest(module=module.name):
                text = module.read_text()
                self.assertNotIn(
                    'pi-permission-system/config.json".source',
                    text,
                )
                self.assertRegex(
                    text,
                    r'pi-permission-system/config\.json" = \{',
                )

    def test_modules_reclaim_the_path_instead_of_backing_it_up(self) -> None:
        """save() replaces the symlink; an un-forced backup collides on the
        following activation and aborts the whole Home Manager run."""
        for module in (
            ROOT / "modules/agents/pi/lib/_home-files.nix",
            ROOT / "modules/agents/omp/default.nix",
        ):
            with self.subTest(module=module.name):
                text = module.read_text()
                block = text.split('pi-permission-system/config.json" = {', 1)[1]
                block = block.split("};", 1)[0]
                self.assertIn("force = true;", block)

    def test_both_modules_parse_the_policy_through_readJsonc(self) -> None:
        pi = (ROOT / "modules/agents/pi/default.nix").read_text()
        omp = (ROOT / "modules/agents/omp/default.nix").read_text()
        for text in (pi, omp):
            self.assertIn('readJsonc "${configDir}/pi/pi-permission-system.jsonc"', text)


if __name__ == "__main__":
    unittest.main()
