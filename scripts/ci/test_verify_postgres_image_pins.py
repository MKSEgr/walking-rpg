import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("verify_postgres_image_pins.py")
SPEC = importlib.util.spec_from_file_location("verify_postgres_image_pins", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)

VALID_COMPOSE = f"""services:
  postgres:
    image: {MODULE.APPROVED_COMPOSE_IMAGE}
    environment:
      POSTGRES_DB: walking_rpg
"""
VALID_FACTORY = MODULE.DEFAULT_FACTORY.read_text(encoding="utf-8")
VALID_CONSUMER = f"""package example;

{MODULE.FACTORY_IMPORT}
import org.testcontainers.postgresql.PostgreSQLContainer;

class ExampleIntegrationTest {{
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();
}}
"""


class VerifyPostgresImagePinsTest(unittest.TestCase):

    def validate_compose(self, source: str) -> list[str]:
        return MODULE.validate_compose_source(source, Path("compose.yaml"))

    def validate_java(
        self,
        consumer: str = VALID_CONSUMER,
        factory: str = VALID_FACTORY,
    ) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            test_root = Path(directory) / "java"
            factory_path = (
                test_root
                / "com"
                / "walkingrpg"
                / "backend"
                / "testsupport"
                / "PostgresTestContainer.java"
            )
            factory_path.parent.mkdir(parents=True)
            factory_path.write_text(factory, encoding="utf-8")
            consumer_path = test_root / "example" / "ExampleIntegrationTest.java"
            consumer_path.parent.mkdir(parents=True)
            consumer_path.write_text(consumer, encoding="utf-8")
            return MODULE.validate_java_sources(test_root, factory_path)

    def test_accepts_reviewed_compose_and_shared_java_factory(self):
        self.assertEqual([], self.validate_compose(VALID_COMPOSE))
        self.assertEqual([], self.validate_java())

    def test_rejects_moving_tag_digest_only_and_wrong_digest(self):
        invalid = (
            MODULE.APPROVED_TAG,
            f"postgres@{MODULE.APPROVED_DIGEST}",
            f"{MODULE.APPROVED_TAG}@sha256:{'1' * 64}",
        )
        for image in invalid:
            with self.subTest(image=image):
                self.assertTrue(
                    self.validate_compose(
                        VALID_COMPOSE.replace(MODULE.APPROVED_COMPOSE_IMAGE, image)
                    )
                )

    def test_rejects_short_uppercase_and_malformed_digests(self):
        invalid = (
            f"{MODULE.APPROVED_TAG}@sha256:{'1' * 63}",
            f"{MODULE.APPROVED_TAG}@sha256:{'A' * 64}",
            f"{MODULE.APPROVED_TAG}@sha512:{'1' * 64}",
        )
        for image in invalid:
            with self.subTest(image=image):
                self.assertTrue(
                    self.validate_compose(
                        VALID_COMPOSE.replace(MODULE.APPROVED_COMPOSE_IMAGE, image)
                    )
                )

    def test_rejects_compose_variable_alias_duplicate_and_multiple_documents(self):
        invalid = (
            VALID_COMPOSE.replace(MODULE.APPROVED_COMPOSE_IMAGE, "${POSTGRES_IMAGE}"),
            (
                f"x-image: &postgres-image {MODULE.APPROVED_COMPOSE_IMAGE}\n"
                "services:\n  postgres:\n    image: *postgres-image\n"
            ),
            (
                "services:\n"
                "  postgres: &postgres-service\n"
                f"    image: {MODULE.APPROVED_COMPOSE_IMAGE}\n"
                "    self: *postgres-service\n"
            ),
            VALID_COMPOSE.replace(
                f"image: {MODULE.APPROVED_COMPOSE_IMAGE}",
                f"image: {MODULE.APPROVED_COMPOSE_IMAGE}\n"
                f"    image: {MODULE.APPROVED_COMPOSE_IMAGE}",
            ),
            VALID_COMPOSE + "---\nservices: {}\n",
        )
        for source in invalid:
            with self.subTest(source=source):
                self.assertTrue(self.validate_compose(source))

    def test_rejects_new_direct_postgres_container_constructor(self):
        constructors = (
            'new PostgreSQLContainer("postgres:17-alpine")',
            'new /* bypass */ PostgreSQLContainer("postgres:17-alpine")',
            (
                "new org.testcontainers.postgresql.\n"
                '    PostgreSQLContainer("postgres:17-alpine")'
            ),
        )
        for constructor in constructors:
            with self.subTest(constructor=constructor):
                direct = VALID_CONSUMER.replace(
                    "PostgresTestContainer.create()",
                    constructor,
                )
                errors = self.validate_java(consumer=direct)
                self.assertTrue(
                    any("direct PostgreSQLContainer" in error for error in errors)
                )

    def test_rejects_mutable_literal_through_generic_container(self):
        invalid = (
            (
                "package example;\n"
                "class ExampleIntegrationTest {\n"
                '  String image = "postgres:latest";\n'
                "}\n"
            ),
            (
                "package example;\n"
                "class ExampleIntegrationTest {\n"
                "  Object image = new GenericContainer(System.getenv(\"PG_IMAGE\"));\n"
                "}\n"
            ),
            (
                "package example;\n"
                "class ExampleIntegrationTest extends PostgreSQLContainer {\n"
                "}\n"
            ),
        )
        for consumer in invalid:
            with self.subTest(consumer=consumer):
                self.assertTrue(self.validate_java(consumer=consumer))

    def test_rejects_missing_factory_import_or_factory_call(self):
        for consumer in (
            VALID_CONSUMER.replace(MODULE.FACTORY_IMPORT + "\n", ""),
            VALID_CONSUMER.replace(
                "PostgresTestContainer.create()",
                "createPostgresElsewhere()",
            ),
        ):
            with self.subTest(consumer=consumer):
                self.assertTrue(self.validate_java(consumer=consumer))

    def test_rejects_factory_tag_digest_or_constructor_drift(self):
        invalid = (
            VALID_FACTORY.replace(MODULE.APPROVED_TAG, "postgres:17-alpine"),
            (
                VALID_FACTORY.replace(MODULE.APPROVED_TAG, "postgres:17-alpine")
                + "\n// public static final String IMAGE_TAG = \""
                + MODULE.APPROVED_TAG
                + "\";\n"
            ),
            VALID_FACTORY.replace(MODULE.APPROVED_DIGEST, "sha256:" + "1" * 64),
            VALID_FACTORY.replace(
                "return new PostgreSQLContainer(DOCKER_IMAGE);",
                "return null;",
            ),
            VALID_FACTORY.replace(
                "public static final String IMAGE_DIGEST =\n"
                f'            "{MODULE.APPROVED_DIGEST}";',
                "public static final String IMAGE_DIGEST =\n"
                '            System.getenv("POSTGRES_IMAGE_DIGEST");\n'
                "    private static final String REVIEWED_DIGEST =\n"
                f'            "{MODULE.APPROVED_DIGEST}";',
            ),
            VALID_FACTORY.replace(
                "private static final DockerImageName DOCKER_IMAGE =\n"
                "            DockerImageName.parse(IMAGE)",
                "private static final String REVIEWED_PARSER =\n"
                '            "DockerImageName.parse(IMAGE)";\n\n'
                "    private static final DockerImageName DOCKER_IMAGE =\n"
                '            DockerImageName.parse(System.getenv("POSTGRES_IMAGE"))',
            ),
            (
                "import static org.testcontainers.utility.DockerImageName.parse;\n\n"
                + VALID_FACTORY.replace(
                    "    public static PostgreSQLContainer create() {\n"
                    "        return new PostgreSQLContainer(DOCKER_IMAGE);\n"
                    "    }",
                    "    private static final DockerImageName ALTERNATE_IMAGE =\n"
                    '            parse(System.getenv("POSTGRES_IMAGE"));\n\n'
                    "    public static PostgreSQLContainer create() {\n"
                    "        return new PostgreSQLContainer(ALTERNATE_IMAGE);\n"
                    "    }",
                )
            ),
        )
        for factory in invalid:
            with self.subTest(factory=factory):
                self.assertTrue(self.validate_java(factory=factory))


if __name__ == "__main__":
    unittest.main()
