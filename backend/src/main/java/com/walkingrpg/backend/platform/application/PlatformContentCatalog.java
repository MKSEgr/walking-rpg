package com.walkingrpg.backend.platform.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import org.springframework.stereotype.Component;

@Component
public class PlatformContentCatalog {

    public enum QuestMetric {
        TOTAL_ACCEPTED_STEPS,
        RESOLVED_EVENTS,
        SQUAD_MEMBERSHIP
    }

    public record PetDefinition(
            String petId,
            String name,
            String evolvedName,
            String species,
            int evolutionBond
    ) {
    }

    public record SkillDefinition(
            String skillId,
            String name,
            String description,
            int requiredSeasonXp
    ) {
    }

    public record QuestDefinition(
            String questId,
            String name,
            QuestMetric metric,
            long target,
            int seasonXpReward,
            int petBondReward
    ) {
    }

    public record CosmeticDefinition(
            String cosmeticId,
            String name,
            String slot,
            long sandboxPrice
    ) {
    }

    public record ExperimentDefinition(
            String experimentId,
            List<String> variants,
            String description
    ) {
        public ExperimentDefinition {
            variants = List.copyOf(variants);
            if (variants.size() < 2) {
                throw new IllegalArgumentException("Эксперимент требует минимум два варианта");
            }
        }
    }

    private final List<String> onboardingSteps = List.of(
            "welcome",
            "health-permission",
            "first-sync",
            "first-expedition"
    );
    private final List<PetDefinition> pets = List.of(
            new PetDefinition("spark-v1", "Искра", "Искра-проводник", "люмин", 50),
            new PetDefinition("moss-v1", "Мох", "Мох-хранитель", "терра", 45),
            new PetDefinition("rune-v1", "Руна", "Руна-навигация", "эхо", 55)
    );
    private final List<SkillDefinition> skills = List.of(
            new SkillDefinition("steady-step", "Ровный шаг",
                    "Добавляет диагностический бонус к стабильным сериям активности.", 0),
            new SkillDefinition("trail-memory", "Память маршрута",
                    "Открывает дополнительное описание пройденных узлов.", 100),
            new SkillDefinition("energy-discipline", "Дисциплина энергии",
                    "Показывает недельный бюджет энергии.", 220),
            new SkillDefinition("signal-reader", "Чтение сигналов",
                    "Открывает расширенные сведения о событиях.", 360)
    );
    private final List<QuestDefinition> quests = List.of(
            new QuestDefinition("walk-3000", "Первый маршрут", QuestMetric.TOTAL_ACCEPTED_STEPS,
                    3_000, 60, 4),
            new QuestDefinition("walk-15000", "Неделя движения", QuestMetric.TOTAL_ACCEPTED_STEPS,
                    15_000, 90, 6),
            new QuestDefinition("resolve-3", "Исследователь", QuestMetric.RESOLVED_EVENTS,
                    3, 80, 5),
            new QuestDefinition("resolve-10", "Навигатор главы", QuestMetric.RESOLVED_EVENTS,
                    10, 140, 8),
            new QuestDefinition("join-squad", "Вместе дальше", QuestMetric.SQUAD_MEMBERSHIP,
                    1, 70, 7)
    );
    private final List<CosmeticDefinition> cosmetics = List.of(
            new CosmeticDefinition("pilot-scarf", "Шарф навигатора", "PILOT", 0),
            new CosmeticDefinition("spark-halo", "Ореол Искры", "PET", 199),
            new CosmeticDefinition("trail-banner", "Знамя маршрута", "PROFILE", 299),
            new CosmeticDefinition("dawn-frame", "Рамка рассвета", "PROFILE", 399)
    );
    private final List<ExperimentDefinition> experiments = List.of(
            new ExperimentDefinition(
                    "home-energy-copy-v1",
                    List.of("CONTROL", "MOTIVATIONAL"),
                    "Текст блока энергии на главном экране"
            ),
            new ExperimentDefinition(
                    "quest-order-v1",
                    List.of("PROGRESS_FIRST", "REWARD_FIRST"),
                    "Порядок информации в карточках заданий"
            )
    );
    private final List<Map<String, Object>> achievements = List.of(
            achievement("onboarding-complete", "Путь открыт"),
            achievement("pet-friend", "Верный спутник"),
            achievement("skill-apprentice", "Ученик пилота"),
            achievement("quest-runner", "Исполнитель"),
            achievement("weekly-route-complete", "Недельный маршрут"),
            achievement("squad-member", "В отряде"),
            achievement("first-cosmetic", "Новый образ"),
            achievement("season-level-3", "Третий уровень сезона")
    );

    public List<String> onboardingSteps() {
        return onboardingSteps;
    }

    public List<PetDefinition> pets() {
        return pets;
    }

    public PetDefinition requirePet(String petId) {
        return pets.stream()
                .filter(item -> item.petId().equals(petId))
                .findFirst()
                .orElseThrow(() -> new PlatformValidationException(
                        "Неизвестный petId", "petId"
                ));
    }

    public List<SkillDefinition> skills() {
        return skills;
    }

    public SkillDefinition requireSkill(String skillId) {
        return skills.stream()
                .filter(item -> item.skillId().equals(skillId))
                .findFirst()
                .orElseThrow(() -> new PlatformValidationException(
                        "Неизвестный skillId", "skillId"
                ));
    }

    public List<QuestDefinition> quests() {
        return quests;
    }

    public QuestDefinition requireQuest(String questId) {
        return quests.stream()
                .filter(item -> item.questId().equals(questId))
                .findFirst()
                .orElseThrow(() -> new PlatformValidationException(
                        "Неизвестный questId", "questId"
                ));
    }

    public List<CosmeticDefinition> cosmetics() {
        return cosmetics;
    }

    public CosmeticDefinition requireCosmetic(String cosmeticId) {
        return cosmetics.stream()
                .filter(item -> item.cosmeticId().equals(cosmeticId))
                .findFirst()
                .orElseThrow(() -> new PlatformValidationException(
                        "Неизвестный cosmeticId", "cosmeticId"
                ));
    }

    public List<ExperimentDefinition> experiments() {
        return experiments;
    }

    public String variantFor(String userId, ExperimentDefinition experiment) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(
                    (experiment.experimentId() + ":" + userId)
                            .getBytes(StandardCharsets.UTF_8)
            );
            int bucket = Byte.toUnsignedInt(digest[0]);
            return experiment.variants().get(bucket % experiment.variants().size());
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 недоступен", exception);
        }
    }

    public Map<String, Object> publicCatalog() {
        Map<String, Object> catalog = new LinkedHashMap<>();
        catalog.put("contentVersion", StarterExpeditionContent.CONTENT_VERSION);
        catalog.put("chapterNodes", 18);
        catalog.put("onboardingSteps", onboardingSteps);
        catalog.put("pets", pets);
        catalog.put("skills", skills);
        catalog.put("quests", quests);
        catalog.put("achievements", achievements);
        catalog.put("cosmetics", cosmetics);
        catalog.put("experiments", experiments);
        catalog.put("season", Map.of(
                "seasonId", "season-1",
                "name", "Сезон первого сигнала",
                "levels", 10
        ));
        catalog.put("weeklyRoute", Map.of(
                "routeId", "weekly-route-1",
                "requiredEnergy", 120
        ));
        catalog.put("materials", List.of(
                StarterInventoryContent.LUMEN_SHARD_ID,
                StarterInventoryContent.ECHO_THREAD_ID,
                StarterInventoryContent.ASH_SEED_ID,
                StarterInventoryContent.PRISM_DUST_ID,
                StarterInventoryContent.ION_BLOOM_ID,
                StarterInventoryContent.DAWN_FRAGMENT_ID
        ));
        catalog.put("catalogDigest", digest(catalog.keySet().toString()));
        return Map.copyOf(catalog);
    }

    private static Map<String, Object> achievement(String id, String name) {
        return Map.of("achievementId", id, "name", name);
    }

    private static String digest(String value) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256")
                            .digest(value.getBytes(StandardCharsets.UTF_8))
            );
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 недоступен", exception);
        }
    }
}
