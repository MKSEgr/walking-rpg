import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify_backend_base_pins.py")
SPEC = importlib.util.spec_from_file_location("verify_backend_base_pins", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)

JDK = MODULE.APPROVED_STAGES[0].image
JRE = MODULE.APPROVED_STAGES[1].image
VALID = f"FROM {JDK} AS build\nRUN true\nFROM {JRE}\nRUN true\n"


class VerifyBackendBasePinsTest(unittest.TestCase):

    def validate(self, source: str) -> list[str]:
        return MODULE.validate_dockerfile_source(source, Path("Dockerfile"))

    def test_accepts_reviewed_tag_and_index_digest_pins(self):
        self.assertEqual([], self.validate(VALID))

    def test_rejects_moving_tag_only_references(self):
        for image in (
            "eclipse-temurin:21-jdk-jammy",
            "eclipse-temurin:21-jre-jammy",
        ):
            with self.subTest(image=image):
                source = VALID.replace(JDK if "jdk" in image else JRE, image)
                self.assertTrue(self.validate(source))

    def test_rejects_digest_only_references(self):
        source = VALID.replace(
            JDK,
            "eclipse-temurin@sha256:" + "1" * 64,
        )
        self.assertTrue(self.validate(source))

    def test_rejects_short_uppercase_and_malformed_digests(self):
        invalid = (
            "eclipse-temurin:21-jdk-jammy@sha256:" + "1" * 63,
            "eclipse-temurin:21-jdk-jammy@sha256:" + "A" * 64,
            "eclipse-temurin:21-jdk-jammy@sha512:" + "1" * 64,
        )
        for image in invalid:
            with self.subTest(image=image):
                self.assertTrue(self.validate(VALID.replace(JDK, image)))

    def test_rejects_arg_and_environment_expressions(self):
        source = (
            "ARG JDK_BASE\n"
            "FROM ${JDK_BASE} AS build\n"
            "ARG JRE_BASE\n"
            "FROM $JRE_BASE\n"
        )
        self.assertTrue(self.validate(source))

    def test_rejects_platform_expression(self):
        source = VALID.replace(
            f"FROM {JDK} AS build",
            f"FROM --platform=$BUILDPLATFORM {JDK} AS build",
        )
        self.assertTrue(self.validate(source))

    def test_rejects_additional_stage(self):
        source = VALID + f"FROM {JRE} AS diagnostics\n"
        errors = self.validate(source)
        self.assertTrue(errors)
        self.assertTrue(any("unexpected additional" in error for error in errors))

    def test_rejects_reordered_stages(self):
        source = f"FROM {JRE}\nFROM {JDK} AS build\n"
        self.assertTrue(self.validate(source))

    def test_rejects_missing_or_changed_stage_alias(self):
        for replacement in (f"FROM {JDK}", f"FROM {JDK} AS compile"):
            with self.subTest(replacement=replacement):
                self.assertTrue(
                    self.validate(VALID.replace(f"FROM {JDK} AS build", replacement))
                )

    def test_rejects_multiline_or_noncanonical_from_instruction(self):
        source = VALID.replace(
            f"FROM {JDK} AS build",
            f"FROM \\\n  {JDK} AS build",
        )
        self.assertTrue(self.validate(source))


if __name__ == "__main__":
    unittest.main()
