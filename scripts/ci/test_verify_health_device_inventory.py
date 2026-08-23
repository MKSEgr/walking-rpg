#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("verify_health_device_inventory.py")
SPEC = importlib.util.spec_from_file_location("health_inventory_validator", MODULE_PATH)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TEMPLATE_PATH = REPOSITORY_ROOT / "docs/evidence/health-device-inventory-template.json"


def template() -> dict:
    return json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))


def recorded() -> dict:
    data = template()
    data.update(
        {
            "recordStatus": "RECORDED",
            "recordedAtUtc": "2026-08-24T09:00:00Z",
            "reviewedAtUtc": "2026-08-24T10:00:00Z",
            "inventoryOwnerRole": "qa_owner",
            "reviewerRole": "release_owner",
        }
    )
    data["evidence"]["storageCategory"] = "approved_internal_evidence"
    values = (
        ("iPhone 15", "iOS 19.0", ["healthkit"], "ios_validation_owner"),
        ("iPhone 14", "iOS 18.6", ["healthkit"], "ios_validation_owner"),
        ("Pixel 9", "Android 16", ["google_fit"], "android_validation_owner"),
        ("Galaxy S25", "Android 16", ["samsung_health"], "android_validation_owner"),
    )
    for slot, (model, os_version, providers, role) in zip(data["slots"], values):
        slot.update(
            {
                "status": "AVAILABLE",
                "deviceModel": model,
                "operatingSystemVersion": os_version,
                "providerCategories": providers,
                "ownerRole": role,
                "blockerCategory": None,
                "blockerReason": None,
            }
        )
        slot["availability"] = {key: True for key in VALIDATOR.AVAILABILITY_KEYS}
    return data


class InventoryValidatorTest(unittest.TestCase):
    def assert_invalid(self, data: dict, message: str | None = None) -> None:
        with self.assertRaises(VALIDATOR.InventoryValidationError) as context:
            VALIDATOR.validate_inventory(data)
        if message:
            self.assertIn(message, str(context.exception))

    def test_committed_template_is_structurally_valid(self) -> None:
        VALIDATOR.validate_inventory(template())

    def test_template_is_not_recorded_evidence(self) -> None:
        with self.assertRaises(VALIDATOR.InventoryValidationError):
            VALIDATOR.validate_inventory(template(), require_recorded=True)

    def test_complete_record_is_valid(self) -> None:
        VALIDATOR.validate_inventory(recorded(), require_recorded=True)

    def test_unknown_field_fails_closed(self) -> None:
        data = recorded()
        data["slots"][0]["serialNumber"] = "redacted"
        self.assert_invalid(data, "unknown=['serialNumber']")

    def test_missing_or_reordered_slot_is_rejected(self) -> None:
        data = recorded()
        data["slots"] = list(reversed(data["slots"]))
        self.assert_invalid(data, "mandatory slot")

    def test_available_slot_requires_every_scenario(self) -> None:
        data = recorded()
        data["slots"][0]["availability"]["batteryMeasurement"] = False
        self.assert_invalid(data, "must be true")

    def test_recorded_slot_cannot_keep_owner_input_status(self) -> None:
        data = recorded()
        data["slots"][0]["status"] = "OWNER_INPUT_REQUIRED"
        self.assert_invalid(data, "AVAILABLE or BLOCKED")

    def test_two_available_android_slots_need_distinct_providers(self) -> None:
        data = recorded()
        data["slots"][3]["providerCategories"] = ["google_fit"]
        self.assert_invalid(data, "two distinct")

    def test_secondary_android_slot_may_be_explicitly_blocked(self) -> None:
        data = recorded()
        slot = data["slots"][3]
        slot.update(
            {
                "status": "BLOCKED",
                "deviceModel": None,
                "operatingSystemVersion": None,
                "providerCategories": [],
                "ownerRole": None,
                "blockerCategory": "provider_unavailable",
                "blockerReason": "No approved secondary provider is currently available.",
            }
        )
        slot["availability"] = {key: None for key in VALIDATOR.AVAILABILITY_KEYS}
        VALIDATOR.validate_inventory(data, require_recorded=True)

    def test_provider_categories_reject_sensitive_identifier_slugs(self) -> None:
        for unsafe in (
            "device_id_123456789012345",
            "serial_abcdef0123456789abcdef0123456789abcdef0123456789",
        ):
            data = recorded()
            data["slots"][2]["providerCategories"] = [unsafe]
            self.assert_invalid(data, "sensitive identifier")

    def test_provider_categories_reject_generic_identifier_like_slugs(self) -> None:
        for unsafe in (
            "provider_123456789012345",
            "provider_abcdef0123456789abcdef0123456789abcdef01",
        ):
            data = recorded()
            data["slots"][2]["providerCategories"] = [unsafe]
            self.assert_invalid(data, "identifiers")

    def test_identifier_like_free_text_is_rejected(self) -> None:
        data = recorded()
        data["slots"][0]["deviceModel"] = "iPhone 123e4567-e89b-12d3-a456-426614174000"
        self.assert_invalid(data, "identifiers")

    def test_url_and_email_are_rejected(self) -> None:
        for unsafe in (
            "See https://internal.invalid",
            "Contact qa@example.com",
            "See folder/file",
        ):
            data = recorded()
            slot = data["slots"][3]
            slot.update(
                {
                    "status": "BLOCKED",
                    "deviceModel": None,
                    "operatingSystemVersion": None,
                    "providerCategories": [],
                    "ownerRole": None,
                    "blockerCategory": "provider_unavailable",
                    "blockerReason": unsafe,
                }
            )
            slot["availability"] = {key: None for key in VALIDATOR.AVAILABILITY_KEYS}
            self.assert_invalid(data, "email, URL")

    def test_strict_loader_rejects_duplicate_json_keys(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "inventory.json"
            path.write_text('{"schemaVersion":"a","schemaVersion":"b"}', encoding="utf-8")
            with self.assertRaises(VALIDATOR.InventoryValidationError):
                VALIDATOR.load_inventory(path)


if __name__ == "__main__":
    unittest.main()
