package com.walkingrpg.backend.equipment.api;

import com.walkingrpg.backend.equipment.application.EquipmentCommandFactory;
import com.walkingrpg.backend.equipment.application.EquipmentService;
import com.walkingrpg.backend.equipment.domain.EquipmentAction;
import com.walkingrpg.backend.equipment.domain.EquipmentResult;
import com.walkingrpg.backend.equipment.domain.EquippedItemResult;
import com.walkingrpg.backend.security.RequestIdentityProvider;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/equipment/slots")
public class EquipmentController {

    private final EquipmentCommandFactory commandFactory;
    private final EquipmentService service;
    private final RequestIdentityProvider identityProvider;

    public EquipmentController(
            EquipmentCommandFactory commandFactory,
            EquipmentService service,
            RequestIdentityProvider identityProvider
    ) {
        this.commandFactory = commandFactory;
        this.service = service;
        this.identityProvider = identityProvider;
    }

    @PostMapping("/{slotId}/equip")
    public EquipmentResponse equip(
            @PathVariable String slotId,
            @Valid @RequestBody EquipmentRequest request
    ) {
        return response(service.change(commandFactory.create(
                identityProvider.requireIdentity().userId(),
                slotId,
                EquipmentAction.EQUIP,
                request
        )));
    }

    @PostMapping("/{slotId}/unequip")
    public EquipmentResponse unequip(
            @PathVariable String slotId,
            @Valid @RequestBody EquipmentRequest request
    ) {
        return response(service.change(commandFactory.create(
                identityProvider.requireIdentity().userId(),
                slotId,
                EquipmentAction.UNEQUIP,
                request
        )));
    }

    private EquipmentResponse response(EquipmentResult result) {
        EquippedItemResult item = result.equippedItem();
        return new EquipmentResponse(
                result.contentVersion(),
                result.slotId(),
                result.slotName(),
                result.slotDescription(),
                result.action().name(),
                result.changed(),
                result.version(),
                item == null
                        ? null
                        : new EquippedItemResponse(
                                item.itemInstanceId(),
                                item.itemId(),
                                item.name(),
                                item.description(),
                                item.equippedAt()
                        ),
                result.serverTime()
        );
    }
}
