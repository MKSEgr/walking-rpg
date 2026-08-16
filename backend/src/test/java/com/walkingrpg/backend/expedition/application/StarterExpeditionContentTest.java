package com.walkingrpg.backend.expedition.application;

import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import com.walkingrpg.backend.expedition.domain.ExpeditionEventChoiceDefinition;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
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
        String chapterV5 = content.activeContentVersion(
                () -> StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
        );
        String chapterV6 = content.activeContentVersion(
                () -> StarterExpeditionContent.CALIBRATED_SEXTANT_CONTENT_VERSION
        );
        String chapterV7 = content.activeContentVersion(
                () -> StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
        );
        String chapterV8 = content.activeContentVersion(
                () -> StarterExpeditionContent
                        .SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION
        );
        String chapterV9 = content.activeContentVersion(
                () -> StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
        );
        String chapterV10 = content.activeContentVersion(
                () -> StarterExpeditionContent
                        .PET_GUIDED_UNCHARTED_CONTENT_VERSION
        );

        assertEquals(StarterExpeditionContent.CONTENT_VERSION, chapterV2);
        assertEquals(StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION, chapterV3);
        assertEquals(StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION, chapterV4);
        assertEquals(StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION,
                chapterV5);
        assertEquals(
                StarterExpeditionContent.CALIBRATED_SEXTANT_CONTENT_VERSION,
                chapterV6
        );
        assertEquals(StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION,
                chapterV7);
        assertEquals(
                StarterExpeditionContent
                        .SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION,
                chapterV8
        );
        assertEquals(
                StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION,
                chapterV9
        );
        assertEquals(
                StarterExpeditionContent.PET_GUIDED_UNCHARTED_CONTENT_VERSION,
                chapterV10
        );
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
        assertFalse(hasPrismSextantChoice(content.eventChoices(
                StarterExpeditionContent.STAR_WELL_EVENT_ID,
                chapterV4
        )));
        assertTrue(hasPrismSextantChoice(content.eventChoices(
                StarterExpeditionContent.STAR_WELL_EVENT_ID,
                chapterV5
        )));
        assertFalse(hasCalibratedSextantChoice(content.eventChoices(
                StarterExpeditionContent.SPECTRUM_OBSERVATORY_EVENT_ID,
                chapterV5
        )));
        List<ExpeditionEventChoiceDefinition> calibratedChoices =
                content.eventChoices(
                        StarterExpeditionContent.SPECTRUM_OBSERVATORY_EVENT_ID,
                        chapterV6
                );
        assertTrue(hasCalibratedSextantChoice(calibratedChoices));
        assertEquals(
                2,
                calibratedChoices.stream()
                        .filter(choice ->
                                StarterExpeditionContent
                                        .CALIBRATED_SEXTANT_CHOICE_ID
                                        .equals(choice.choiceId()))
                        .findFirst()
                        .orElseThrow()
                        .equipmentRequirement()
                        .minimumUpgradeLevel()
        );
        assertFalse(hasSecondDawnChoice(content.eventChoices(
                StarterExpeditionContent.FINAL_EVENT_ID,
                chapterV6
        )));
        assertTrue(hasSecondDawnChoice(content.eventChoices(
                StarterExpeditionContent.FINAL_EVENT_ID,
                chapterV7
        )));
        assertTrue(hasSecondDawnChoice(content.eventChoices(
                StarterExpeditionContent.FINAL_EVENT_ID,
                chapterV8
        )));
        assertTrue(StarterExpeditionContent.supportsSecondDawnAttunement(
                chapterV8
        ));
        assertTrue(StarterExpeditionContent.supportsSecondDawnAttunement(
                chapterV9
        ));
        assertTrue(StarterExpeditionContent.supportsSecondDawnAttunement(
                chapterV10
        ));
        assertFalse(StarterExpeditionContent.supportsSecondDawnAttunement(
                chapterV7
        ));
        assertFalse(hasUnchartedVergeChoice(content.eventChoices(
                StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                chapterV8
        )));
        List<ExpeditionEventChoiceDefinition> unchartedChoices =
                content.eventChoices(
                        StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                        chapterV9
                );
        assertTrue(hasUnchartedVergeChoice(unchartedChoices));
        assertEquals(
                3,
                unchartedChoices.stream()
                        .filter(choice -> StarterExpeditionContent
                                .UNCHARTED_VERGE_ROUTE_CHOICE_ID
                                .equals(choice.choiceId()))
                        .findFirst()
                        .orElseThrow()
                        .equipmentRequirement()
                        .minimumUpgradeLevel()
        );
        assertFalse(hasPetGuidedChoice(content.eventChoices(
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                chapterV9
        )));
        List<ExpeditionEventChoiceDefinition> petGuidedChoices =
                content.eventChoices(
                        StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                        chapterV10
                );
        assertEquals(5, petGuidedChoices.size());
        assertEquals(
                List.of("spark-v1", "moss-v1", "rune-v1"),
                petGuidedChoices.stream()
                        .filter(choice -> choice.petRequirement() != null)
                        .map(choice -> choice.petRequirement().petId())
                        .toList()
        );
        assertTrue(StarterExpeditionContent.supportsStormRift(chapterV4));
        assertTrue(StarterExpeditionContent.supportsResonanceRoute(chapterV3));
        assertEquals(
                StarterExpeditionContent.UNCHARTED_VERGE_NODE_COUNT,
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

    @Test
    void shouldRouteThroughSpectrumObservatoryAndRejoinAtHorizonSpire() {
        assertEquals(
                StarterExpeditionContent.SPECTRUM_OBSERVATORY_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.STAR_WELL_EVENT_ID,
                        StarterExpeditionContent.PRISM_SEXTANT_ROUTE_CHOICE_ID,
                        StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.HORIZON_SPIRE_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.SPECTRUM_OBSERVATORY_EVENT_ID,
                        "chart-invisible-constellation",
                        StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
    }

    @Test
    void shouldRouteThroughSecondDawnAndCompleteAfterItsEvent() {
        assertEquals(
                StarterExpeditionContent.SECOND_DAWN_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.FINAL_EVENT_ID,
                        StarterExpeditionContent.SECOND_DAWN_ROUTE_CHOICE_ID,
                        StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertTrue(content.nextNodeAfterEvent(
                StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                "anchor-second-dawn",
                StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
        ).isEmpty());
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
        ).size());
    }

    @Test
    void shouldCrossUnchartedVergeOnlyInChapterV9AndCompleteThere() {
        assertThrows(
                EventResolutionValidationException.class,
                () -> content.requireChoice(
                        StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                        StarterExpeditionContent.UNCHARTED_VERGE_ROUTE_CHOICE_ID,
                        StarterExpeditionContent
                                .SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION
                )
        );
        assertEquals(
                StarterExpeditionContent.UNCHARTED_VERGE_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                        StarterExpeditionContent.UNCHARTED_VERGE_ROUTE_CHOICE_ID,
                        StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertTrue(content.nextNodeAfterEvent(
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                "deploy-return-beacon",
                StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
        ).isEmpty());
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
        ).size());
        assertThrows(
                EventResolutionValidationException.class,
                () -> content.requireChoice(
                        StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                        StarterExpeditionContent.MOSS_UNCHARTED_CHOICE_ID,
                        StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
                )
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

    private boolean hasPrismSextantChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.PRISM_SEXTANT_ROUTE_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }

    private boolean hasCalibratedSextantChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.CALIBRATED_SEXTANT_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }

    private boolean hasSecondDawnChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.SECOND_DAWN_ROUTE_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }

    private boolean hasUnchartedVergeChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.UNCHARTED_VERGE_ROUTE_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }

    private boolean hasPetGuidedChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                choice.petRequirement() != null
        );
    }
}
