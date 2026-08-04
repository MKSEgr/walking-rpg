package com.walkingrpg.backend.equipment.api;

import java.time.Instant;
import java.util.UUID;

import com.walkingrpg.backend.equipment.application.EquipmentCommandFactory;
import com.walkingrpg.backend.equipment.application.EquipmentItemUnavailableException;
import com.walkingrpg.backend.equipment.application.EquipmentService;
import com.walkingrpg.backend.equipment.application.StarterEquipmentContent;
import com.walkingrpg.backend.equipment.domain.EquipmentAction;
import com.walkingrpg.backend.equipment.domain.EquipmentCommand;
import com.walkingrpg.backend.equipment.domain.EquipmentResult;
import com.walkingrpg.backend.equipment.domain.EquippedItemResult;
import com.walkingrpg.backend.security.FixedRequestIdentityProvider;
import com.walkingrpg.backend.shared.api.ApiExceptionHandler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class EquipmentControllerTest {

    private static final Instant NOW = Instant.parse("2026-08-01T12:00:00Z");
    private static final UUID ITEM_INSTANCE_ID = UUID.fromString(
            "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    );

    private EquipmentService service;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        service = mock(EquipmentService.class);
        mockMvc = MockMvcBuilders.standaloneSetup(new EquipmentController(
                        new EquipmentCommandFactory(),
                        service,
                        FixedRequestIdentityProvider.user("user-1")
                ))
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldReturnEquippedItem() throws Exception {
        when(service.change(any())).thenReturn(new EquipmentResult(
                StarterEquipmentContent.CONTENT_VERSION,
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                "Навигационный прибор",
                "Один уникальный инструмент.",
                EquipmentAction.EQUIP,
                true,
                1,
                new EquippedItemResult(
                        ITEM_INSTANCE_ID,
                        "resonance-compass",
                        "Резонансный компас",
                        "Уникальный прибор.",
                        NOW
                ),
                NOW
        ));

        mockMvc.perform(post("/api/v1/equipment/slots/NAVIGATION/equip")
                        .contentType("application/json")
                        .content("""
                                {
                                  "itemInstanceId": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
                                  "idempotencyKey": "equip-1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.action").value("EQUIP"))
                .andExpect(jsonPath("$.changed").value(true))
                .andExpect(jsonPath("$.equippedItem.itemInstanceId")
                        .value(ITEM_INSTANCE_ID.toString()));

        ArgumentCaptor<EquipmentCommand> command = ArgumentCaptor.forClass(
                EquipmentCommand.class
        );
        verify(service).change(command.capture());
        assertEquals(ITEM_INSTANCE_ID, command.getValue().itemInstanceId());
    }

    @Test
    void shouldReturnStableUnavailableItemError() throws Exception {
        when(service.change(any())).thenThrow(
                new EquipmentItemUnavailableException(ITEM_INSTANCE_ID)
        );

        mockMvc.perform(post("/api/v1/equipment/slots/NAVIGATION/equip")
                        .contentType("application/json")
                        .content("""
                                {
                                  "itemInstanceId": "11111111-2222-3333-4444-555555555555",
                                  "idempotencyKey": "equip-1"
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code")
                        .value("EQUIPMENT_ITEM_UNAVAILABLE"))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }

    @Test
    void shouldRejectItemInstanceOnUnequip() throws Exception {
        mockMvc.perform(post("/api/v1/equipment/slots/NAVIGATION/unequip")
                        .contentType("application/json")
                        .content("""
                                {
                                  "itemInstanceId": "11111111-2222-3333-4444-555555555555",
                                  "idempotencyKey": "unequip-1"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.field")
                        .value("itemInstanceId"));
    }

    @Test
    void shouldRejectShortenedItemInstanceIdBeforeService() throws Exception {
        mockMvc.perform(post("/api/v1/equipment/slots/NAVIGATION/equip")
                        .contentType("application/json")
                        .content("""
                                {
                                  "itemInstanceId": "1-1-1-1-1",
                                  "idempotencyKey": "equip-shortened-uuid"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.field")
                        .value("itemInstanceId"));

        verifyNoInteractions(service);
    }
}
