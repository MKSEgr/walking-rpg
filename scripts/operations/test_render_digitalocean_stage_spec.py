import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("render_digitalocean_stage_spec.py")
SPEC = importlib.util.spec_from_file_location("digitalocean_stage_spec", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class DigitalOceanStageSpecTest(unittest.TestCase):
    def values(self, **overrides: str):
        values = {
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
        self.assertIn('cluster_name: "walking-rpg-alpha-pg-fra"', rendered)
        self.assertIn("value: ${alpha-db.PASSWORD}", rendered)
        self.assertIn("value: ${alpha-db.CA_CERT}", rendered)
        self.assertIn("deploy_on_push: false", rendered)
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


if __name__ == "__main__":
    unittest.main()
