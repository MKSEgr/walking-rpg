package com.walkingrpg.backend.expedition.application;

import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import com.walkingrpg.backend.expedition.domain.ExpeditionEventChoiceDefinition;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class StarterExpeditionContentTest {

    private final StarterExpeditionContent content = new StarterExpeditionContent();

    @Test
    void shouldGateOptionalRoutesByActiveContentVersion() {
        AtomicInteger activationReads = new AtomicInteger();
        String chapterV2 = content.activeContentVersion(
                () -> StarterExpeditionContent.CONTENT_VERSION
        );
        String chapterV3 = content.activeContentVersion(
                () -> StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
        );
        String chapterV4 = content.activeContentVersion(
                () -> {
                    activationReads.incrementAndGet();
                    return StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION;
                }
        );

        assertEquals(StarterExpeditionContent.CONTENT_VERSION, chapterV2);
        assertEquals(StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION, chapterV3);
        assertEquals(StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION, chapterV4);
        assertEquals(1, activationReads.get());
        assertEquals(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION,
                content.activeContentVersion(() -> null)
        );
        assertEquals(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION,
                content.activeContentVersion(() -> "chapter-2-v1")
        );
        assertFalse(hasStormRiftChoice(content.eventChoices(
                StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                chapterV2
        )));
        assertTrue(hasStormRiftChoice(content.eventChoices(
                StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                chapterV3
        )));
        assertFalse(hasVoidOrchardChoice(content.eventChoices(
                StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                chapterV3
        )));
        assertTrue(hasVoidOrchardChoice(content.eventChoices(
                StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                chapterV4
        )));
        assertTrue(StarterExpeditionContent.supportsStormRift(chapterV4));
        assertTrue(StarterExpeditionContent.supportsResonanceRoute(chapterV3));
        assertEquals(
                StarterExpeditionContent.VOID_ORCHARD_NODE_COUNT,
                content.nodes().size()
        );
    }

    @Test
    void shouldRejoinMainRouteAfterStormRift() {
        var ordinaryChoice = content.eventChoices(
                StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                StarterExpeditionContent.CONTENT_VERSION
        ).getFirst();

        assertEquals(
                StarterExpeditionContent.EMBER_STATION_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                        ordinaryChoice.choiceId(),
                        StarterExpeditionContent.CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.STORM_RIFT_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                        StarterExpeditionContent.STORM_RIFT_CHOICE_ID,
                        StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.EMBER_STATION_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.STORM_RIFT_EVENT_ID,
                        content.eventChoices(
                                StarterExpeditionContent.STORM_RIFT_EVENT_ID,
                                StarterExpeditionContent.CONTENT_VERSION
                        ).getFirst().choiceId(),
                        StarterExpeditionContent.CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
    }

    @Test
    void shouldForkAtVoidOrchardAndRejoinAtStarWell() {
        var ordinaryChoice = content.eventChoices(
                StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
        ).getFirst();

        assertEquals(
                StarterExpeditionContent.STAR_WELL_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                        ordinaryChoice.choiceId(),
                        StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.ROOT_MEMORY_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                        StarterExpeditionContent.ROOT_ECHO_CHOICE_ID,
                        StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.LIGHT_CANOPY_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                        StarterExpeditionContent.LIGHT_CANOPY_CHOICE_ID,
                        StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.STAR_WELL_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.ROOT_MEMORY_EVENT_ID,
                        content.eventChoices(
                                StarterExpeditionContent.ROOT_MEMORY_EVENT_ID
                        ).getFirst().choiceId(),
                        StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.STAR_WELL_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.LIGHT_CANOPY_EVENT_ID,
                        content.eventChoices(
                                StarterExpeditionContent.LIGHT_CANOPY_EVENT_ID
                        ).getFirst().choiceId(),
                        StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
    }

    private boolean hasStormRiftChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.STORM_RIFT_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }

    private boolean hasVoidOrchardChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.ROOT_ECHO_CHOICE_ID.equals(
                        choice.choiceId()
                ) || StarterExpeditionContent.LIGHT_CANOPY_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }
}
