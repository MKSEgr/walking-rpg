package com.walkingrpg.backend.equipment.application;

import java.util.Locale;
import java.util.UUID;

import com.walkingrpg.backend.equipment.api.EquipmentRequest;
import com.walkingrpg.backend.equipment.domain.EquipmentAction;
import com.walkingrpg.backend.equipment.domain.EquipmentCommand;
import org.springframework.stereotype.Component;

@Component
public class EquipmentCommandFactory {

    public EquipmentCommand create(
            String userId,
            String slotId,
            EquipmentAction action,
            EquipmentRequest request
    ) {
        if (action == EquipmentAction.UNEQUIP
                && request.itemInstanceId() != null
                && !request.itemInstanceId().isBlank()) {
            throw new EquipmentValidationException(
                    "UNEQUIP не принимает itemInstanceId",
                    "itemInstanceId"
            );
        }
        return new EquipmentCommand(
                requireText(userId, "userId", 128),
                requireText(slotId, "slotId", 64).toUpperCase(Locale.ROOT),
                action,
                action == EquipmentAction.EQUIP
                        ? parseItemInstanceId(request.itemInstanceId())
                        : null,
                requireText(request.idempotencyKey(), "idempotencyKey", 128)
        );
    }

    private UUID parseItemInstanceId(String value) {
        String normalized = requireText(value, "itemInstanceId", 36);
        try {
            return UUID.fromString(normalized);
        } catch (IllegalArgumentException exception) {
            throw new EquipmentValidationException(
                    "itemInstanceId должен быть UUID",
                    "itemInstanceId"
            );
        }
    }

    private String requireText(String value, String field, int maxLength) {
        if (value == null || value.isBlank()) {
            throw new EquipmentValidationException(field + " обязателен", field);
        }
        String normalized = value.trim();
        if (normalized.length() > maxLength) {
            throw new EquipmentValidationException(
                    field + " превышает " + maxLength + " символов",
                    field
            );
        }
        return normalized;
    }
}
