import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

/// Localizes mutable Platform catalog copy by stable backend identity.
///
/// Unknown content keeps the literal server value so a newer backend remains
/// readable. Persisted journey decisions and recaps must never use this
/// resolver because they are immutable records of what the player saw.
extension CurrentPlatformContentLocalizations on AppLocalizations {
  String currentPlatformOnboardingStep(String stepId, String fallback) {
    return switch (stepId) {
      'welcome' => platformOnboardingWelcome,
      'health-permission' => platformOnboardingHealthPermission,
      'first-sync' => platformOnboardingFirstSync,
      'pet-selection' => platformOnboardingPetSelection,
      'first-expedition' => platformOnboardingFirstExpedition,
      'first-event' => platformOnboardingFirstEvent,
      _ => fallback,
    };
  }

  String currentPlatformSkillName(String skillId, String fallback) {
    return switch (skillId) {
      'steady-step' => platformSkillSteadyStepName,
      'trail-memory' => platformSkillTrailMemoryName,
      'energy-discipline' => platformSkillEnergyDisciplineName,
      'signal-reader' => platformSkillSignalReaderName,
      _ => fallback,
    };
  }

  String currentPlatformSkillDescription(String skillId, String fallback) {
    return switch (skillId) {
      'steady-step' => platformSkillSteadyStepDescription,
      'trail-memory' => platformSkillTrailMemoryDescription,
      'energy-discipline' => platformSkillEnergyDisciplineDescription,
      'signal-reader' => platformSkillSignalReaderDescription,
      _ => fallback,
    };
  }

  String currentPlatformQuestName(String questId, String fallback) {
    return switch (questId) {
      'walk-3000' => platformQuestWalk3000Name,
      'walk-15000' => platformQuestWalk15000Name,
      'resolve-3' => platformQuestResolve3Name,
      'resolve-10' => platformQuestResolve10Name,
      'join-squad' => platformQuestJoinSquadName,
      _ => fallback,
    };
  }

  String currentPlatformAchievementName(
    String achievementId,
    String fallback,
  ) {
    return switch (achievementId) {
      'onboarding-complete' => platformAchievementOnboardingCompleteName,
      'pet-friend' => platformAchievementPetFriendName,
      'skill-apprentice' => platformAchievementSkillApprenticeName,
      'quest-runner' => platformAchievementQuestRunnerName,
      'weekly-route-complete' => platformAchievementWeeklyRouteName,
      'squad-member' => platformAchievementSquadMemberName,
      'first-cosmetic' => platformAchievementFirstCosmeticName,
      'season-level-3' => platformAchievementSeasonLevel3Name,
      _ => fallback,
    };
  }

  String currentPlatformCosmeticName(String cosmeticId, String fallback) {
    return switch (cosmeticId) {
      'pilot-scarf' => platformCosmeticPilotScarfName,
      'spark-halo' => platformCosmeticSparkHaloName,
      'trail-banner' => platformCosmeticTrailBannerName,
      'dawn-frame' => platformCosmeticDawnFrameName,
      _ => fallback,
    };
  }

  String currentPlatformSeasonName(String seasonId, String fallback) {
    return seasonId == 'signal-season-1'
        ? platformSeasonFirstSignalName
        : fallback;
  }

  String currentPlatformExperimentDescription(
    String experimentId,
    String fallback,
  ) {
    return switch (experimentId) {
      'home-energy-copy-v1' => platformExperimentHomeEnergyDescription,
      'quest-order-v1' => platformExperimentQuestOrderDescription,
      _ => fallback,
    };
  }

  String currentPlatformCommandMessage(String commandType, String fallback) {
    return switch (commandType.toUpperCase()) {
      'COMPLETE_ONBOARDING_STEP' => platformCommandOnboardingUpdated,
      'SELECT_PET' => platformCommandCompanionSelected,
      'EVOLVE_PET' => platformCommandCompanionEvolved,
      'UNLOCK_SKILL' => platformCommandSkillUnlocked,
      'CLAIM_QUEST' => platformCommandQuestClaimed,
      'ADVANCE_WEEKLY_ROUTE' => platformCommandWeeklyRouteAdvanced,
      'CREATE_SQUAD' => platformCommandSquadCreated,
      'JOIN_SQUAD' => platformCommandSquadJoined,
      'LEAVE_SQUAD' => platformCommandSquadLeft,
      'PURCHASE_COSMETIC' || 'BUY_COSMETIC' =>
        platformCommandCosmeticPurchased,
      'EQUIP_COSMETIC' => platformCommandCosmeticEquipped,
      'CLAIM_SEASON_REWARD' => platformCommandSeasonRewardClaimed,
      _ => fallback,
    };
  }
}
