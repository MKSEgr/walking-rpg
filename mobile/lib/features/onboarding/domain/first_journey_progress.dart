import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';

enum FirstJourneyStage { welcome, activity, pet, expedition, event, complete }

final class FirstJourneyProgress {
  FirstJourneyProgress({required this.home, required this.platform})
    : completedSteps = Set<String>.unmodifiable(
        _effectiveCompletedSteps(home, platform),
      );

  static const String welcomeStep = 'welcome';
  static const String healthPermissionStep = 'health-permission';
  static const String firstSyncStep = 'first-sync';
  static const String petSelectionStep = 'pet-selection';
  static const String firstExpeditionStep = 'first-expedition';
  static const String firstEventStep = 'first-event';

  static const List<String> steps = <String>[
    welcomeStep,
    healthPermissionStep,
    firstSyncStep,
    petSelectionStep,
    firstExpeditionStep,
    firstEventStep,
  ];

  static const Set<String> _factBackedSteps = <String>{
    healthPermissionStep,
    firstSyncStep,
    firstExpeditionStep,
    firstEventStep,
  };

  final HomeSnapshot home;
  final PlatformSnapshot platform;
  final Set<String> completedSteps;

  FirstJourneyStage get stage {
    if (!completedSteps.contains(welcomeStep)) {
      return FirstJourneyStage.welcome;
    }
    if (!completedSteps.contains(healthPermissionStep) ||
        !completedSteps.contains(firstSyncStep)) {
      return FirstJourneyStage.activity;
    }
    if (!completedSteps.contains(petSelectionStep)) {
      return FirstJourneyStage.pet;
    }
    if (!completedSteps.contains(firstExpeditionStep)) {
      return FirstJourneyStage.expedition;
    }
    if (!completedSteps.contains(firstEventStep)) {
      return FirstJourneyStage.event;
    }
    return FirstJourneyStage.complete;
  }

  bool get complete => stage == FirstJourneyStage.complete;

  bool get readOnly => home.isCached || platform.isCached;

  double get progressValue {
    final int completed = steps
        .where(completedSteps.contains)
        .length
        .clamp(0, steps.length)
        .toInt();
    return completed / steps.length;
  }

  int get completedCount => steps
      .where(completedSteps.contains)
      .length
      .clamp(0, steps.length)
      .toInt();

  List<String> get pendingFactMilestones {
    final Set<String> persisted = platform.userState.completedOnboardingSteps;
    return steps
        .where(_factBackedSteps.contains)
        .where(completedSteps.contains)
        .where((String step) => !persisted.contains(step))
        .toList(growable: false);
  }

  static Set<String> _effectiveCompletedSteps(
    HomeSnapshot home,
    PlatformSnapshot platform,
  ) {
    final Set<String> persisted = platform.userState.completedOnboardingSteps;
    final Set<String> completed = persisted
        .where((String step) => !_factBackedSteps.contains(step))
        .toSet();
    final bool hasDurableActivitySync =
        home.lastActivitySyncAt != null ||
        platform.userState.totalAcceptedSteps > 0;
    if (hasDurableActivitySync) {
      completed
        ..add(healthPermissionStep)
        ..add(firstSyncStep);
    }

    final HomeExpeditionEvent? event = home.unlockedEvent;
    final bool firstEventResolved =
        platform.userState.resolvedEventCount > 0 ||
        (event?.eventId == 'signal-source-v1' && event?.isResolved == true) ||
        home.currentNodeId != 'outer-beacon' ||
        home.expeditionStatus == 'COMPLETED';
    final bool firstEventReady =
        event?.eventId == 'signal-source-v1' && event?.isResolved == false;
    if (firstEventReady || firstEventResolved) {
      completed.add(firstExpeditionStep);
    }
    if (firstEventResolved) {
      completed.add(firstEventStep);
    }
    return completed;
  }
}
