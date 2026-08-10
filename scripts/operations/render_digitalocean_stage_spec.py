#!/usr/bin/env python3
"""Render the non-secret DigitalOcean stage App Spec deterministically."""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TEMPLATE = ROOT / "infra" / "digitalocean" / "app.yaml.template"
PLACEHOLDER_PATTERN = re.compile(r"@@[A-Z0-9_]+@@")
POSTGRES_IDENTIFIER = re.compile(r"^[a-z_][a-z0-9_]{0,62}$")
CLUSTER_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{1,62}$")
OCI_IMAGE_DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
GIT_OBJECT_ID = re.compile(r"^[0-9a-f]{40}$")


@dataclass(frozen=True)
class StageSpecValues:
    backend_image_digest: str
    backend_source_git_sha: str
    backend_source_git_tree: str
    postgres_cluster_name: str
    postgres_database: str
    postgres_user: str
    oidc_issuer_uri: str
    oidc_jwk_set_uri: str
    oidc_audience: str

    def replacements(self) -> dict[str, str]:
        return {
            "@@BACKEND_IMAGE_DIGEST@@": self.backend_image_digest,
            "@@BACKEND_SOURCE_GIT_SHA@@": self.backend_source_git_sha,
            "@@BACKEND_SOURCE_GIT_TREE@@": self.backend_source_git_tree,
            "@@POSTGRES_CLUSTER_NAME@@": self.postgres_cluster_name,
            "@@POSTGRES_DATABASE@@": self.postgres_database,
            "@@POSTGRES_USER@@": self.postgres_user,
            "@@OIDC_ISSUER_URI@@": self.oidc_issuer_uri,
            "@@OIDC_JWK_SET_URI@@": self.oidc_jwk_set_uri,
            "@@OIDC_AUDIENCE@@": self.oidc_audience,
        }


def required_environment(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError(f"{name} is required")
    return value


def https_url(name: str, value: str, *, trailing_slash: bool = False) -> str:
    parsed = urlsplit(value)
    if (
        parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError(f"{name} must be an HTTPS URL without credentials, query or fragment")
    if trailing_slash and (parsed.path != "/" or not value.endswith("/")):
        raise ValueError(f"{name} must be an HTTPS origin ending with /")
    if '"' in value or "\n" in value or "\r" in value:
        raise ValueError(f"{name} contains unsupported YAML characters")
    return value


def values_from_environment() -> StageSpecValues:
    image_digest = required_environment("STAGE_BACKEND_IMAGE_DIGEST")
    source_git_sha = required_environment("STAGE_BACKEND_SOURCE_GIT_SHA")
    source_git_tree = required_environment("STAGE_BACKEND_SOURCE_GIT_TREE")
    cluster_name = required_environment("STAGE_POSTGRES_CLUSTER_NAME")
    database = os.environ.get("STAGE_POSTGRES_DATABASE", "walking_rpg").strip()
    user = os.environ.get("STAGE_POSTGRES_USER", "walking_rpg_app").strip()
    issuer = https_url(
        "STAGE_OIDC_ISSUER_URI",
        required_environment("STAGE_OIDC_ISSUER_URI"),
        trailing_slash=True,
    )
    jwks = https_url(
        "STAGE_OIDC_JWK_SET_URI",
        required_environment("STAGE_OIDC_JWK_SET_URI"),
    )
    audience = https_url(
        "STAGE_OIDC_AUDIENCE",
        required_environment("STAGE_OIDC_AUDIENCE"),
    )

    if not OCI_IMAGE_DIGEST.fullmatch(image_digest) or image_digest == "sha256:" + "0" * 64:
        raise ValueError(
            "STAGE_BACKEND_IMAGE_DIGEST must be a lowercase sha256 OCI digest"
        )
    if not GIT_OBJECT_ID.fullmatch(source_git_sha) or source_git_sha == "0" * 40:
        raise ValueError(
            "STAGE_BACKEND_SOURCE_GIT_SHA must be a 40-character lowercase Git SHA"
        )
    if not GIT_OBJECT_ID.fullmatch(source_git_tree) or source_git_tree == "0" * 40:
        raise ValueError(
            "STAGE_BACKEND_SOURCE_GIT_TREE must be a 40-character lowercase Git tree"
        )
    if not CLUSTER_NAME.fullmatch(cluster_name):
        raise ValueError("STAGE_POSTGRES_CLUSTER_NAME has an invalid format")
    if not POSTGRES_IDENTIFIER.fullmatch(database):
        raise ValueError("STAGE_POSTGRES_DATABASE must be a canonical PostgreSQL identifier")
    if not POSTGRES_IDENTIFIER.fullmatch(user):
        raise ValueError("STAGE_POSTGRES_USER must be a canonical PostgreSQL identifier")

    issuer_url = urlsplit(issuer)
    jwks_url = urlsplit(jwks)
    if (issuer_url.scheme, issuer_url.netloc) != (jwks_url.scheme, jwks_url.netloc):
        raise ValueError("Auth0 issuer and JWKS URL must use the same HTTPS origin")
    if jwks_url.path != "/.well-known/jwks.json":
        raise ValueError("STAGE_OIDC_JWK_SET_URI must end with /.well-known/jwks.json")

    return StageSpecValues(
        backend_image_digest=image_digest,
        backend_source_git_sha=source_git_sha,
        backend_source_git_tree=source_git_tree,
        postgres_cluster_name=cluster_name,
        postgres_database=database,
        postgres_user=user,
        oidc_issuer_uri=issuer,
        oidc_jwk_set_uri=jwks,
        oidc_audience=audience,
    )


def render(template: str, values: StageSpecValues) -> str:
    rendered = template
    replacements = values.replacements()
    for placeholder, replacement in replacements.items():
        count = rendered.count(placeholder)
        if count != 1:
            raise ValueError(f"template must contain {placeholder} exactly once, found {count}")
        rendered = rendered.replace(placeholder, replacement)

    unresolved = sorted(set(PLACEHOLDER_PATTERN.findall(rendered)))
    if unresolved:
        raise ValueError(f"unresolved template placeholders: {', '.join(unresolved)}")
    if (
        "sslmode=require" in rendered
        or "github:" in rendered
        or "deploy_on_push:" in rendered
        or "\n      tag:" in rendered
    ):
        raise ValueError("rendered stage spec weakens a fail-closed deployment invariant")
    for required in (
        "registry_type: GHCR",
        "repository: walking-rpg-backend",
        f'digest: "{values.backend_image_digest}"',
        f'value: "{values.backend_source_git_sha}"',
        f'value: "{values.backend_source_git_tree}"',
        "value: ${alpha-db.HOSTNAME}",
        "value: ${alpha-db.CA_CERT}",
        "http_path: /readyz",
        "http_path: /livez",
        "enhanced_threat_control_enabled: true",
    ):
        if required not in rendered:
            raise ValueError(f"rendered stage spec is missing required contract: {required}")
    return rendered.rstrip() + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Render a deployable DigitalOcean App Spec without repository secrets."
    )
    parser.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        template = args.template.read_text(encoding="utf-8")
        result = render(template, values_from_environment())
    except (OSError, ValueError) as error:
        print(f"DigitalOcean stage spec rejected: {error}", file=sys.stderr)
        return 1
    sys.stdout.write(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
