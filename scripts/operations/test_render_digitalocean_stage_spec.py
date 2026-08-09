import importlib.util
import sys
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).with_name("render_digitalocean_stage_spec.py")
SPEC = importlib.util.spec_from_file_location("digitalocean_stage_spec", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class DigitalOceanStageSpecTest(unittest.TestCase):
    def values(self, **overrides: str):
        values = {
            "backend_image_digest": "sha256:" + "a" * 64,
            "backend_source_git_sha": "1" * 40,
            "backend_source_git_tree": "2" * 40,
            "postgres_cluster_name": "walking-rpg-alpha-pg-fra",
            "postgres_database": "walking_rpg",
            "postgres_user": "walking_rpg_app",
            "oidc_issuer_uri": "https://walking-rpg-alpha.eu.auth0.com/",
            "oidc_jwk_set_uri": (
                "https://walking-rpg-alpha.eu.auth0.com/.well-known/jwks.json"
            ),
            "oidc_audience": "https://api.stepbeyond.game",
        }
        values.update(overrides)
        return MODULE.StageSpecValues(**values)

    def test_renders_all_external_values_and_preserves_bindables(self):
        template = MODULE.DEFAULT_TEMPLATE.read_text(encoding="utf-8")

        rendered = MODULE.render(template, self.values())

        self.assertNotIn("@@", rendered)
        self.assertNotIn("github:", rendered)
        self.assertNotIn("branch:", rendered)
        self.assertNotIn("deploy_on_push:", rendered)
        self.assertNotIn("tag:", rendered)
        self.assertIn("registry_type: GHCR", rendered)
        self.assertIn("repository: walking-rpg-backend", rendered)
        self.assertIn('digest: "sha256:' + "a" * 64 + '"', rendered)
        self.assertIn('value: "' + "1" * 40 + '"', rendered)
        self.assertIn('value: "' + "2" * 40 + '"', rendered)
        self.assertIn('cluster_name: "walking-rpg-alpha-pg-fra"', rendered)
        self.assertIn("value: ${alpha-db.PASSWORD}", rendered)
        self.assertIn("value: ${alpha-db.CA_CERT}", rendered)
        self.assertIn("http_path: /readyz", rendered)
        self.assertIn("http_path: /livez", rendered)

    def test_rejects_an_unexpected_placeholder(self):
        with self.assertRaisesRegex(ValueError, "unresolved template placeholders"):
            MODULE.render(
                MODULE.DEFAULT_TEMPLATE.read_text(encoding="utf-8")
                + "unknown: @@UNREVIEWED_VALUE@@\n",
                self.values(),
            )

    def test_rejects_missing_required_contract(self):
        template = MODULE.DEFAULT_TEMPLATE.read_text(encoding="utf-8").replace(
            "http_path: /readyz", "http_path: /"
        )

        with self.assertRaisesRegex(ValueError, "missing required contract"):
            MODULE.render(template, self.values())

    def test_https_url_rejects_credentials_and_query(self):
        for value in (
            "http://tenant.eu.auth0.com/",
            "https://user@tenant.eu.auth0.com/",
            "https://tenant.eu.auth0.com/?unsafe=true",
        ):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    MODULE.https_url("issuer", value, trailing_slash=True)

    def test_environment_rejects_moving_or_noncanonical_image_identity(self):
        valid_environment = {
            "STAGE_BACKEND_IMAGE_DIGEST": "sha256:" + "a" * 64,
            "STAGE_BACKEND_SOURCE_GIT_SHA": "1" * 40,
            "STAGE_BACKEND_SOURCE_GIT_TREE": "2" * 40,
            "STAGE_POSTGRES_CLUSTER_NAME": "walking-rpg-alpha-pg-fra",
            "STAGE_POSTGRES_DATABASE": "walking_rpg",
            "STAGE_POSTGRES_USER": "walking_rpg_app",
            "STAGE_OIDC_ISSUER_URI": "https://walking-rpg-alpha.eu.auth0.com/",
            "STAGE_OIDC_JWK_SET_URI": (
                "https://walking-rpg-alpha.eu.auth0.com/.well-known/jwks.json"
            ),
            "STAGE_OIDC_AUDIENCE": "https://api.stepbeyond.game",
        }
        invalid_values = {
            "STAGE_BACKEND_IMAGE_DIGEST": (
                "ghcr.io/mksegr/walking-rpg-backend:latest"
            ),
            "STAGE_BACKEND_SOURCE_GIT_SHA": "master",
            "STAGE_BACKEND_SOURCE_GIT_TREE": "A" * 40,
        }

        for name, value in invalid_values.items():
            with self.subTest(name=name, value=value):
                environment = dict(valid_environment)
                environment[name] = value
                with mock.patch.dict(MODULE.os.environ, environment, clear=True):
                    with self.assertRaises(ValueError):
                        MODULE.values_from_environment()

        zero_placeholders = {
            "STAGE_BACKEND_IMAGE_DIGEST": "sha256:" + "0" * 64,
            "STAGE_BACKEND_SOURCE_GIT_SHA": "0" * 40,
            "STAGE_BACKEND_SOURCE_GIT_TREE": "0" * 40,
        }
        for name, value in zero_placeholders.items():
            with self.subTest(name=name, value=value):
                environment = dict(valid_environment)
                environment[name] = value
                with mock.patch.dict(MODULE.os.environ, environment, clear=True):
                    with self.assertRaises(ValueError):
                        MODULE.values_from_environment()

    def test_rejects_a_moving_source_template(self):
        template = MODULE.DEFAULT_TEMPLATE.read_text(encoding="utf-8").replace(
            "    image:\n"
            "      registry_type: GHCR\n"
            "      registry: mksegr\n"
            "      repository: walking-rpg-backend\n"
            '      digest: "@@BACKEND_IMAGE_DIGEST@@"\n',
            "    github:\n"
            "      repo: MKSEgr/walking-rpg\n"
            "      branch: master\n"
            "      deploy_on_push: false\n"
            '    # rejected digest placeholder: "@@BACKEND_IMAGE_DIGEST@@"\n',
        )

        with self.assertRaisesRegex(ValueError, "fail-closed deployment invariant"):
            MODULE.render(template, self.values())


if __name__ == "__main__":
    unittest.main()
