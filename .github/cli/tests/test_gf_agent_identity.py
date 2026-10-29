import hashlib
import json
import math
import struct
import subprocess
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from jsonschema.validators import validator_for


ROOT = Path(__file__).resolve().parents[3]
KIT = ROOT / "docs" / "brand" / "gf-agent-identity"


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def contrast(foreground, background):
    def luminance(value):
        channels = [int(value[index:index + 2], 16) / 255 for index in (1, 3, 5)]
        linear = [
            channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4
            for channel in channels
        ]
        return sum(weight * channel for weight, channel in zip((0.2126, 0.7152, 0.0722), linear))
    high, low = sorted((luminance(foreground), luminance(background)), reverse=True)
    return (high + 0.05) / (low + 0.05)


class GfAgentIdentityIntakeTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(
            (KIT / "intake-manifest.json").is_file(),
            "The curated, provenance-recorded identity intake is missing.",
        )
        self.config = load_json(KIT / "config" / "agent-identity.json")
        self.palette = load_json(KIT / "config" / "palette.json")

    def test_imported_inventory_matches_hashes_and_has_no_unrecorded_assets(self):
        manifest = load_json(KIT / "intake-manifest.json")
        records = manifest["files"]
        self.assertEqual(len({record["sourcePath"] for record in records}), len(records))
        destinations = {record["path"] for record in records}
        self.assertEqual(len(destinations), len(records))
        for record in records:
            relative = Path(record["path"])
            with self.subTest(path=str(relative)):
                self.assertFalse(relative.is_absolute())
                self.assertNotIn("..", relative.parts)
                target = KIT / relative
                self.assertTrue(target.is_file())
                content = target.read_bytes()
                self.assertEqual(len(content), record["bytes"])
                self.assertEqual(hashlib.sha256(content).hexdigest(), record["sha256"])
                if record["role"] == "reference-only":
                    self.assertTrue(record["path"].endswith(".txt"))
        actual = {
            path.relative_to(KIT).as_posix()
            for folder in ("config", "agents", "brand", "visuals", "reference")
            for path in (KIT / folder).rglob("*")
            if path.is_file()
        }
        self.assertEqual(actual, destinations)

    def test_source_configuration_conforms_to_its_supplied_schema(self):
        schema = load_json(KIT / "config" / "agent-identity.schema.json")
        validator = validator_for(schema)
        validator.check_schema(schema)
        validator(schema).validate(self.config)

    def test_imported_bytes_are_not_subject_to_git_line_ending_conversion(self):
        manifest = load_json(KIT / "intake-manifest.json")
        paths = [
            (KIT.relative_to(ROOT) / record["path"]).as_posix()
            for record in manifest["files"]
        ]
        result = subprocess.run(
            ["git", "check-attr", "--stdin", "text"],
            cwd=ROOT,
            input=("\n".join(paths) + "\n").encode("utf-8"),
            capture_output=True,
            check=True,
        )
        lines = result.stdout.decode("utf-8").splitlines()
        self.assertEqual(len(lines), len(paths))
        for line in lines:
            path, attribute = line.rsplit(": text: ", 1)
            self.assertEqual(attribute, "unset", f"Imported bytes require Git -text protection: {path}")

    def test_all_catalogue_names_are_unique_and_environment_safe(self):
        records = self.config["agents"]
        self.assertEqual(len(records), 37)
        self.assertEqual(len({record["id"] for record in records}), len(records))
        self.assertEqual(len({record["derived"]["slug"] for record in records}), len(records))
        names = []
        for record in records:
            base = " ".join(
                item for item in (record["po"], record["domain"], record.get("scope", "")) if item
            )
            with self.subTest(agent=record["id"]):
                self.assertLessEqual(len(base), 25)
                names.append(base.casefold())
                identity = load_json(
                    KIT / "agents" / record["derived"]["slug"] / "identity" / "identity.json"
                )
                scoped = record.get("environmentScoped", True)
                self.assertEqual(
                    set(identity["displayName"]),
                    {"DEV", "TEST", "PROD"} if scoped else {"PROD"},
                )
                for environment in ("DEV", "TEST", "PROD"):
                    expected = base
                    if scoped and environment != "PROD":
                        expected += " " + environment
                    self.assertEqual(record["derived"]["displayName"][environment], expected)
                    if scoped or environment == "PROD":
                        self.assertEqual(identity["displayName"][environment], expected)
                    self.assertLessEqual(len(expected), 30)
                for key in ("schemaName", "solutionUniqueName", "envVarPrefix", "slug"):
                    value = record["derived"].get(key)
                    if value:
                        self.assertNotRegex(value, r"(?i)(?:dev|test|prod)$")
        self.assertEqual(len(set(names)), len(names))

    def test_every_agent_has_the_expected_icons_without_external_svg_content(self):
        for record in self.config["agents"]:
            folder = KIT / "agents" / record["derived"]["slug"] / "identity"
            environments = ("DEV", "TEST", "PROD") if record.get("environmentScoped", True) else ("PROD",)
            for environment in environments:
                suffix = "" if environment == "PROD" else "-" + environment.lower()
                for size in (192, 32):
                    with self.subTest(agent=record["id"], environment=environment, size=size):
                        content = (folder / f"color-{size}{suffix}.png").read_bytes()
                        self.assertEqual(content[:8], b"\x89PNG\r\n\x1a\n")
                        self.assertEqual(struct.unpack(">II", content[16:24]), (size, size))
                        self.assertLessEqual(len(content), 100 * 1024)
            outline = (folder / "outline-32.png").read_bytes()
            self.assertEqual(struct.unpack(">II", outline[16:24]), (32, 32))
            self.assertEqual(outline[25], 6, "Outline requires an RGBA alpha channel.")
            for source in folder.glob("*.svg"):
                svg = ET.fromstring(source.read_bytes())
                for element in svg.iter():
                    self.assertNotEqual(element.tag.rsplit("}", 1)[-1], "script")
                    for attribute, value in element.attrib.items():
                        self.assertFalse(attribute.lower().startswith("on"))
                        if attribute.rsplit("}", 1)[-1] in ("href", "src"):
                            self.assertTrue(value.startswith("#") or value.startswith("data:"))

    def test_journey_and_environment_contrast_meets_the_required_threshold(self):
        for identifier, domain in self.palette["domains"].items():
            with self.subTest(journey=identifier):
                measured = contrast(domain["glyph"], domain["background"])
                self.assertGreaterEqual(measured, 4.5)
                self.assertTrue(math.isclose(measured, domain["contrast"], abs_tol=0.02))
        for environment in ("DEV", "TEST"):
            marker = self.palette["environments"][environment]
            self.assertGreaterEqual(contrast(marker["label"], marker["band"]), 4.5)
        self.assertIsNone(self.palette["environments"]["PROD"])

    def test_four_adopted_bindings_resolve_to_exact_source_identities(self):
        bindings = load_json(KIT / "agent-bindings.json")
        expected = {
            "IDEA-GF-POLICY": "D3-A01",
            "IDEA-GF-RECRUITING": "D1-A01",
            "IDEA-GF-HR-OPERATIONS": "D2-A01",
            "IDEA-GF-ESS": "D3-A02",
        }
        self.assertEqual({row["packageId"]: row["identityId"] for row in bindings["bindings"]}, expected)
        by_id = {record["id"]: record for record in self.config["agents"]}
        for row in bindings["bindings"]:
            record = by_id[row["identityId"]]
            self.assertEqual(row["identityPath"], f'agents/{record["derived"]["slug"]}/identity/identity.json')
            self.assertEqual(row["runtimeHarness"], "copilot-studio-github")
            self.assertFalse(row["deployed"])
            self.assertEqual(row["technicalNames"], "pending-gf-owner-decisions")
            self.assertTrue((KIT / row["identityPath"]).is_file())
            self.assertTrue((ROOT / row["specification"]).is_file())

    def test_upstream_automation_is_reference_only_and_not_enabled(self):
        manifest = load_json(KIT / "intake-manifest.json")
        for row in manifest["files"]:
            if row["sourcePath"].startswith(("scripts/", "pipelines/", "github/")):
                self.assertEqual(row["role"], "reference-only")
                self.assertTrue(row["path"].endswith(".txt"))
        self.assertFalse(any(KIT.rglob("*.py")))
        self.assertFalse(any(KIT.rglob("*.js")))
        self.assertFalse(any(KIT.rglob("*.yml")))
        self.assertFalse(any(KIT.rglob("*.instructions.md")))
        self.assertTrue((KIT / "reference" / "THIRD-PARTY-NOTICES.md.txt").is_file())


if __name__ == "__main__":
    unittest.main()
