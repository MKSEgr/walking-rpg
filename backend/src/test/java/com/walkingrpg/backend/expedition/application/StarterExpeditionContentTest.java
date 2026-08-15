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
    void shouldGateStormRiftEntryByActiveContentVersion() {
        AtomicInteger activationReads = new AtomicInteger();
        String chapterV2 = content.activeContentVersion(
                () -> StarterExpeditionContent.CONTENT_VERSION
        );
        String chapterV3 = content.activeContentVersion(
                () -> {
                    activationReads.incrementAndGet();
                    return StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION;
                }
        );

        assertEquals(StarterExpeditionContent.CONTENT_VERSION, chapterV2);
        assertEquals(StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION, chapterV3);
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
        assertTrue(StarterExpeditionContent.supportsResonanceRoute(chapterV3));
        assertEquals(
                StarterExpeditionContent.STORM_RIFT_NODE_COUNT,
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

    private boolean hasStormRiftChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.STORM_RIFT_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }
}
