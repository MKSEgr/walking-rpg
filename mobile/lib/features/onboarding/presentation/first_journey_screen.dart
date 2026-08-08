import 'dart:async';

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_locale_controller.dart';
import 'package:walking_rpg_mobile/core/localization/app_locale_scope.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/core/localization/mandatory_journey_localizations.dart';
import 'package:walking_rpg_mobile/design_system/activity_intake_signal.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/event_choice_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_event_scene.dart';
import 'package:walking_rpg_mobile/design_system/expedition_item_art.dart';
import 'package:walking_rpg_mobile/design_system/expedition_node_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_progress_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/first_journey_route_signal.dart';
import 'package:walking_rpg_mobile/design_system/progression_gain_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/onboarding/domain/first_journey_progress.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/recovery/presentation/mobile_command_recovery_action.dart';

enum _FirstJourneyAppAction { language, account }

double _firstJourneyTextScale(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(16) / 16;
}

bool _usesCompactFirstJourneyChrome(
  BuildContext context,
  BoxConstraints constraints,
) {
  return constraints.maxWidth < 360 ||
      (constraints.maxWidth < 430 && _firstJourneyTextScale(context) > 1.3);
}

bool _usesCompactFirstJourneySection(
  BuildContext context,
  BoxConstraints constraints,
) {
  return constraints.maxWidth < 300 ||
      (constraints.maxWidth < 400 && _firstJourneyTextScale(context) > 1.3);
}

class FirstJourneyScreen extends StatelessWidget {
  const FirstJourneyScreen({
    super.key,
    required this.progress,
    required this.busy,
    required this.onWelcome,
    required this.onSync,
    required this.onSelectPet,
    required this.onAdvance,
    required this.onResolve,
    required this.onContinueAfterActivity,
    required this.onFinish,
    required this.onContinueLater,
    this.onOpenAccount,
    this.onOpenRecovery,
    this.recoveryCount = 0,
    this.recoveryUnavailable = false,
    this.activityReward,
    this.eventReward,
    this.errorMessage,
    this.notice,
  });

  final FirstJourneyProgress progress;
  final bool busy;
  final VoidCallback onWelcome;
  final VoidCallback onSync;
  final ValueChanged<String> onSelectPet;
  final VoidCallback onAdvance;
  final ValueChanged<HomeEventChoice> onResolve;
  final VoidCallback onContinueAfterActivity;
  final VoidCallback onFinish;
  final VoidCallback onContinueLater;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenRecovery;
  final int recoveryCount;
  final bool recoveryUnavailable;
  final ActivitySyncResult? activityReward;
  final EventResolutionResult? eventReward;
  final String? errorMessage;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compactChrome = _usesCompactFirstJourneyChrome(
          context,
          constraints,
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.l10n.firstJourneyTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: <Widget>[
              MobileCommandRecoveryAction(
                key: const Key('first-journey-recovery'),
                onPressed: onOpenRecovery,
                count: recoveryCount,
                unavailable: recoveryUnavailable,
              ),
              if (compactChrome)
                _FirstJourneyAppActionsMenu(onOpenAccount: onOpenAccount),
              if (!compactChrome) const AppLocaleMenuButton(),
              if (!compactChrome)
                IconButton(
                  tooltip: context.l10n.accountTooltip,
                  onPressed: onOpenAccount,
                  icon: const Icon(Icons.account_circle_outlined),
                ),
            ],
          ),
          body: ExpeditionBackdrop(
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool compactSection = _usesCompactFirstJourneySection(
                    context,
                    constraints,
                  );
                  return SingleChildScrollView(
                    key: const Key('first-journey-scroll'),
                    padding: EdgeInsets.fromLTRB(
                      compactSection ? 12 : 20,
                      compactSection ? 14 : 18,
                      compactSection ? 12 : 20,
                      28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _JourneyProgressHeader(progress: progress),
                            if (progress.readOnly) ...<Widget>[
                              const SizedBox(height: 12),
                              ExpeditionNotice(
                                key: const Key(
                                  'first-journey-read-only-signal',
                                ),
                                label: context.l10n.firstJourneySavedBadge,
                                icon: Icons.cloud_off_outlined,
                                message: context.l10n.firstJourneySavedMessage,
                              ),
                            ],
                            if (notice != null) ...<Widget>[
                              const SizedBox(height: 12),
                              ExpeditionNotice(
                                key: const Key('first-journey-notice-signal'),
                                label:
                                    context.l10n.firstJourneyRouteNoticeBadge,
                                icon: Icons.info_outline,
                                message: notice!,
                                tone: ExpeditionNoticeTone.lumen,
                              ),
                            ],
                            if (errorMessage != null) ...<Widget>[
                              const SizedBox(height: 12),
                              ExpeditionNotice(
                                key: const Key('first-journey-error-signal'),
                                label: context.l10n.firstJourneyErrorBadge,
                                icon: Icons.sync_problem_outlined,
                                message: errorMessage!,
                                tone: ExpeditionNoticeTone.resonance,
                              ),
                            ],
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 360),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.04, 0.02),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                              child: _stageContent(context),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              key: const Key('first-journey-continue-later'),
                              onPressed: busy ? null : onContinueLater,
                              child: Text(context.l10n.continueLater),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stageContent(BuildContext context) {
    final EventResolutionResult? completedEvent = eventReward;
    if (completedEvent != null) {
      return _CompletionPanel(
        key: const ValueKey<String>('first-journey-complete'),
        result: completedEvent,
        busy: busy,
        onFinish: onFinish,
      );
    }
    final ActivitySyncResult? activity = activityReward;
    if (activity != null) {
      return _ActivityRewardPanel(
        key: const ValueKey<String>('first-journey-energy-reward'),
        result: activity,
        dailyGoal: progress.home.dailyGoal,
        busy: busy,
        onContinue: onContinueAfterActivity,
      );
    }

    return switch (progress.stage) {
      FirstJourneyStage.welcome => _WelcomePanel(
        key: const ValueKey<String>('first-journey-welcome'),
        busy: busy || progress.readOnly,
        onContinue: onWelcome,
      ),
      FirstJourneyStage.activity => _ActivityPanel(
        key: const ValueKey<String>('first-journey-activity'),
        busy: busy || progress.readOnly,
        onSync: onSync,
      ),
      FirstJourneyStage.pet => _PetSelectionPanel(
        key: const ValueKey<String>('first-journey-pet'),
        pets: progress.platform.userState.pets,
        busy: busy || progress.readOnly,
        onSelect: onSelectPet,
      ),
      FirstJourneyStage.expedition => _ExpeditionPanel(
        key: const ValueKey<String>('first-journey-expedition'),
        home: progress.home,
        busy: busy || progress.readOnly,
        onAdvance: onAdvance,
        onSync: onSync,
      ),
      FirstJourneyStage.event => _EventPanel(
        key: const ValueKey<String>('first-journey-event'),
        event: progress.home.unlockedEvent,
        busy: busy || progress.readOnly,
        onResolve: onResolve,
      ),
      FirstJourneyStage.complete => _AlreadyCompletePanel(
        key: const ValueKey<String>('first-journey-already-complete'),
        busy: busy,
        onFinish: onFinish,
      ),
    };
  }
}

class _FirstJourneyAppActionsMenu extends StatelessWidget {
  const _FirstJourneyAppActionsMenu({required this.onOpenAccount});

  final VoidCallback? onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_FirstJourneyAppAction>(
      key: const Key('first-journey-more-actions'),
      tooltip: context.l10n.moreActionsTooltip,
      icon: const Icon(Icons.more_vert),
      onSelected: (_FirstJourneyAppAction action) {
        switch (action) {
          case _FirstJourneyAppAction.language:
            final AppLocaleController? controller = AppLocaleScope.maybeOf(
              context,
            );
            if (controller != null) {
              unawaited(showAppLocalePicker(context, controller));
            }
            break;
          case _FirstJourneyAppAction.account:
            onOpenAccount?.call();
            break;
        }
      },
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<_FirstJourneyAppAction>>[
            PopupMenuItem<_FirstJourneyAppAction>(
              key: const Key('first-journey-menu-language'),
              value: _FirstJourneyAppAction.language,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.language, size: 21),
                  const SizedBox(width: 12),
                  Flexible(child: Text(context.l10n.changeLanguageTooltip)),
                ],
              ),
            ),
            PopupMenuItem<_FirstJourneyAppAction>(
              key: const Key('first-journey-menu-account'),
              value: _FirstJourneyAppAction.account,
              enabled: onOpenAccount != null,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.account_circle_outlined, size: 21),
                  const SizedBox(width: 12),
                  Flexible(child: Text(context.l10n.accountTooltip)),
                ],
              ),
            ),
          ],
    );
  }
}

class _JourneyProgressHeader extends StatelessWidget {
  const _JourneyProgressHeader({required this.progress});

  final FirstJourneyProgress progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = _usesCompactFirstJourneySection(
          context,
          constraints,
        );
        final String count =
            '${progress.completedCount}/${FirstJourneyProgress.steps.length}';
        return Column(
          key: Key(
            compact
                ? 'first-journey-progress-compact'
                : 'first-journey-progress-wide',
          ),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (compact) ...<Widget>[
              Text(
                context.l10n.firstJourneyProgressTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ExpeditionBadge(
                label: context.l10n.firstJourneyCompletedSteps(
                  progress.completedCount,
                ),
                icon: Icons.route_outlined,
                allowWrap: true,
              ),
            ] else
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.l10n.firstJourneyProgressTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(count, style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: FirstJourneyRouteSignal(
                steps: FirstJourneyProgress.steps,
                completedSteps: progress.completedSteps,
                height: compact ? 88 : 96,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    super.key,
    required this.busy,
    required this.onContinue,
  });

  final bool busy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _JourneyPanel(
      icon: Icons.radar,
      visual: ChapterVista(
        key: const Key('first-journey-chapter-vista'),
        semanticLabel: context.l10n.welcomeVistaSemanticLabel,
      ),
      eyebrow: context.l10n.welcomeEyebrow,
      title: context.l10n.welcomeTitle,
      body: context.l10n.welcomeBody,
      highlights: <String>[
        context.l10n.welcomeHighlightWalk,
        context.l10n.welcomeHighlightServer,
        context.l10n.welcomeHighlightGoal,
      ],
      action: FilledButton.icon(
        key: const Key('first-journey-start'),
        onPressed: busy ? null : onContinue,
        icon: const Icon(Icons.arrow_forward),
        label: _JourneyActionLabel(context.l10n.welcomeStartButton),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({super.key, required this.busy, required this.onSync});

  final bool busy;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return _JourneyPanel(
      icon: Icons.directions_walk,
      visual: const ActivityIntakeSignal(
        key: Key('first-journey-activity-intake-signal'),
      ),
      eyebrow: context.l10n.activityEyebrow,
      title: context.l10n.activityTitle,
      body: context.l10n.activityBody,
      highlights: <String>[
        context.l10n.activityHighlightCountOnly,
        context.l10n.activityHighlightIdempotent,
        context.l10n.activityHighlightRate,
      ],
      action: FilledButton.icon(
        key: const Key('first-journey-sync'),
        onPressed: busy ? null : onSync,
        icon: busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.health_and_safety_outlined),
        label: _JourneyActionLabel(
          busy
              ? context.l10n.activityConnectingButton
              : context.l10n.activityConnectButton,
        ),
      ),
    );
  }
}

class _ActivityRewardPanel extends StatelessWidget {
  const _ActivityRewardPanel({
    super.key,
    required this.result,
    required this.dailyGoal,
    required this.busy,
    required this.onContinue,
  });

  final ActivitySyncResult result;
  final int dailyGoal;
  final bool busy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final String reward = result.energyGranted > 0
        ? '+${result.energyGranted} ENERGY'
        : context.l10n.activityStepsConnected;
    final double dailyProgress = dailyGoal <= 0
        ? 0
        : (result.acceptedTotal / dailyGoal).clamp(0, 1).toDouble();
    final String dailyPercentage = '${(dailyProgress * 100).round()}%';
    return _JourneyPanel(
      icon: Icons.bolt,
      visual: Center(
        child: ExpeditionProgressRing(
          key: const Key('first-journey-daily-route-orbit'),
          progress: dailyProgress,
          value: dailyPercentage,
          label: context.l10n.stepsLabel,
          size: 108,
        ),
      ),
      eyebrow: context.l10n.activityRewardEyebrow,
      title: reward,
      body: context.l10n.activityRewardBody(
        result.acceptedTotal,
        dailyGoal,
        result.energyBalanceAfter,
      ),
      highlights: <String>[
        if (result.energyGranted == 0)
          context.l10n.activityRewardNeedMore
        else
          context.l10n.activityRewardAvailable,
        context.l10n.activityRiskStatus(
          context.l10n.journeyRiskStatus(result.riskStatus),
        ),
      ],
      action: FilledButton.icon(
        key: const Key('first-journey-activity-continue'),
        onPressed: busy ? null : onContinue,
        icon: const Icon(Icons.pets_outlined),
        label: _JourneyActionLabel(context.l10n.choosePetButton),
      ),
      accent: true,
    );
  }
}

class _PetSelectionPanel extends StatelessWidget {
  const _PetSelectionPanel({
    super.key,
    required this.pets,
    required this.busy,
    required this.onSelect,
  });

  final List<PlatformPet> pets;
  final bool busy;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _JourneyPanel(
      icon: Icons.pets,
      eyebrow: context.l10n.petEyebrow,
      title: context.l10n.petTitle,
      body: context.l10n.petBody,
      child: Column(
        children: pets
            .map(
              (PlatformPet pet) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PetChoice(
                  pet: pet,
                  busy: busy,
                  onSelect: () => onSelect(pet.petId),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _PetChoice extends StatelessWidget {
  const _PetChoice({
    required this.pet,
    required this.busy,
    required this.onSelect,
  });

  final PlatformPet pet;
  final bool busy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String petName = context.l10n.journeyPetName(pet.petId, pet.name);
    final String petSpecies = context.l10n.journeyPetSpecies(
      pet.petId,
      pet.species,
    );
    final String petTrait = context.l10n.journeyPetTrait(pet.petId, pet.trait);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = _usesCompactFirstJourneySection(
          context,
          constraints,
        );
        final Widget portrait = CompanionPortrait(
          key: Key('first-journey-pet-portrait-${pet.petId}'),
          petId: pet.petId,
          name: petName,
          species: petSpecies,
          evolutionStage: pet.evolutionStage,
          active: pet.active,
          size: compact ? 72 : 78,
        );
        final Widget details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(petName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                ExpeditionBadge(
                  label: petSpecies,
                  icon: Icons.blur_circular,
                  allowWrap: compact,
                ),
                ExpeditionBadge(
                  label: context.l10n.petForm(pet.evolutionStage + 1),
                  icon: Icons.auto_awesome_outlined,
                  tone: pet.evolutionStage > 0
                      ? ExpeditionPanelTone.resonance
                      : ExpeditionPanelTone.neutral,
                  allowWrap: compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              petTrait,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        );
        return Material(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.72),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('first-journey-select-${pet.petId}'),
            onTap: busy ? null : onSelect,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 16),
              child: compact
                  ? Column(
                      key: Key('first-journey-pet-compact-${pet.petId}'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Align(alignment: Alignment.centerLeft, child: portrait),
                        const SizedBox(height: 12),
                        details,
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Flexible(child: Text(context.l10n.chooseCompanion)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios, size: 18),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      key: Key('first-journey-pet-wide-${pet.petId}'),
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        portrait,
                        const SizedBox(width: 16),
                        Expanded(child: details),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, size: 18),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ExpeditionPanel extends StatelessWidget {
  const _ExpeditionPanel({
    super.key,
    required this.home,
    required this.busy,
    required this.onAdvance,
    required this.onSync,
  });

  final HomeSnapshot home;
  final bool busy;
  final VoidCallback onAdvance;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final bool canAdvance = home.spendableEnergy > 0;
    final int remaining = home.remainingExpeditionEnergy;
    final String nodeName = context.l10n.journeyNodeName(
      home.currentNodeId,
      home.currentNodeName,
    );
    return _JourneyPanel(
      icon: Icons.explore_outlined,
      visual: ChapterVista(
        key: const Key('first-journey-expedition-vista'),
        semanticLabel: context.l10n.expeditionVistaSemanticLabel(nodeName),
        progress: home.expeditionProgressValue,
      ),
      eyebrow: context.l10n.expeditionEyebrow,
      title: nodeName,
      body: context.l10n.expeditionBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${home.expeditionProgress} / ${home.requiredEnergy} ENERGY',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ExpeditionProgressSignal(
            expeditionId: home.expeditionId,
            progress: home.expeditionProgress,
            target: home.requiredEnergy,
          ),
          const SizedBox(height: 8),
          Text(context.l10n.expeditionBalance(home.availableEnergy, remaining)),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('first-journey-advance'),
            onPressed: busy
                ? null
                : canAdvance
                ? onAdvance
                : onSync,
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(canAdvance ? Icons.bolt : Icons.directions_walk),
            label: _JourneyActionLabel(
              canAdvance
                  ? context.l10n.expeditionAdvanceButton(home.spendableEnergy)
                  : context.l10n.expeditionSyncStepsButton,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventPanel extends StatelessWidget {
  const _EventPanel({
    super.key,
    required this.event,
    required this.busy,
    required this.onResolve,
  });

  final HomeExpeditionEvent? event;
  final bool busy;
  final ValueChanged<HomeEventChoice> onResolve;

  @override
  Widget build(BuildContext context) {
    final HomeExpeditionEvent? current = event;
    if (current == null) {
      return _JourneyPanel(
        icon: Icons.sync_problem_outlined,
        eyebrow: context.l10n.eventUpdatingEyebrow,
        title: context.l10n.eventNotReadyTitle,
        body: context.l10n.eventNotReadyBody,
      );
    }
    final String eventTitle = context.l10n.journeyEventTitle(
      current.eventId,
      current.title,
    );
    final String eventSummary = context.l10n.journeyEventSummary(
      current.eventId,
      current.summary,
    );
    return _JourneyPanel(
      icon: Icons.auto_awesome_outlined,
      visual: ExpeditionEventScene(
        eventId: current.eventId,
        eventTitle: eventTitle,
        fallbackSemanticLabel: context.l10n.eventFallbackScene(eventTitle),
      ),
      eyebrow: context.l10n.eventEyebrow,
      title: eventTitle,
      body: eventSummary,
      child: Column(
        children: current.choices
            .map(
              (HomeEventChoice choice) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton(
                  key: Key('first-journey-choice-${choice.choiceId}'),
                  onPressed: busy ? null : () => onResolve(choice),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.centerLeft,
                  ),
                  child: EventChoiceSignalLayout(
                    eventId: current.eventId,
                    choiceId: choice.choiceId,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.journeyChoiceTitle(
                            current.eventId,
                            choice.choiceId,
                            choice.title,
                          ),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.journeyChoiceDescription(
                            current.eventId,
                            choice.choiceId,
                            choice.description,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.eventChoiceRewards(
                            choice.pilotExperienceReward,
                            choice.petBondReward,
                          ),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _CompletionPanel extends StatelessWidget {
  const _CompletionPanel({
    super.key,
    required this.result,
    required this.busy,
    required this.onFinish,
  });

  final EventResolutionResult result;
  final bool busy;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final EventNextNode? nextNode = result.nextNode;
    final String eventTitle = context.l10n.journeyEventTitle(
      result.eventId,
      result.eventTitle,
    );
    final String choiceTitle = context.l10n.journeyChoiceTitle(
      result.eventId,
      result.choiceId,
      result.choiceTitle,
    );
    final String outcomeTitle = context.l10n.journeyOutcomeTitle(
      result.eventId,
      result.choiceId,
      result.outcomeTitle,
    );
    final String outcomeSummary = context.l10n.journeyOutcomeSummary(
      result.eventId,
      result.choiceId,
      result.outcomeSummary,
    );
    return _JourneyPanel(
      icon: Icons.emoji_events_outlined,
      visual: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ExpeditionEventScene(
            eventId: result.eventId,
            eventTitle: eventTitle,
            fallbackSemanticLabel: context.l10n.eventCompletedScene(eventTitle),
          ),
          const SizedBox(height: 12),
          EventChoiceSignalLayout(
            eventId: result.eventId,
            choiceId: result.choiceId,
            child: Text(
              context.l10n.eventSelectedChoice(choiceTitle),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          if (nextNode != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              context.l10n.eventNextNodeLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.walkingRpgPalette.resonance,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ExpeditionNodeSignal(
                nodeId: nextNode.nodeId,
                nodeName: context.l10n.journeyNodeName(
                  nextNode.nodeId,
                  nextNode.name,
                ),
                completed: false,
                role: ExpeditionNodeSignalRole.next,
                markSize: 46,
              ),
            ),
          ],
        ],
      ),
      eyebrow: context.l10n.eventCompletionEyebrow,
      title: outcomeTitle,
      body: outcomeSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ProgressionGainSignalLayout(
            kind: ProgressionGainKind.pilotExperience,
            subjectId: result.pilot.pilotId,
            child: Text(
              context.l10n.eventPilotExperience(result.pilot.experienceGained),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 8),
          ProgressionGainSignalLayout(
            kind: ProgressionGainKind.petBond,
            subjectId: result.pet.petId,
            child: Text(
              context.l10n.eventPetBond(
                result.pet.bondGained,
                context.l10n.journeyPetName(result.pet.petId, result.pet.name),
              ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          if (result.material != null) ...<Widget>[
            const SizedBox(height: 8),
            _JourneyRewardLine(
              leading: ExpeditionItemEmblem(
                itemId: result.material!.itemId,
                size: 44,
                highlighted: true,
              ),
              text:
                  '+${result.material!.quantityGained} '
                  '${result.material!.name}',
            ),
          ],
        ],
      ),
      action: FilledButton.icon(
        key: const Key('first-journey-finish'),
        onPressed: busy ? null : onFinish,
        icon: const Icon(Icons.explore),
        label: _JourneyActionLabel(context.l10n.openExpeditionButton),
      ),
      accent: true,
    );
  }
}

class _AlreadyCompletePanel extends StatelessWidget {
  const _AlreadyCompletePanel({
    super.key,
    required this.busy,
    required this.onFinish,
  });

  final bool busy;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return _JourneyPanel(
      icon: Icons.emoji_events_outlined,
      eyebrow: context.l10n.journeyCompleteEyebrow,
      title: context.l10n.journeyCompleteTitle,
      body: context.l10n.journeyCompleteBody,
      action: FilledButton.icon(
        key: const Key('first-journey-finish'),
        onPressed: busy ? null : onFinish,
        icon: const Icon(Icons.explore),
        label: _JourneyActionLabel(context.l10n.openExpeditionButton),
      ),
      accent: true,
    );
  }
}

class _JourneyRewardLine extends StatelessWidget {
  const _JourneyRewardLine({required this.leading, required this.text});

  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        leading,
        const SizedBox(width: 9),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.labelLarge),
        ),
      ],
    );
  }
}

class _JourneyActionLabel extends StatelessWidget {
  const _JourneyActionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.center,
    );
  }
}

class _JourneyPanel extends StatelessWidget {
  const _JourneyPanel({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.highlights = const <String>[],
    this.action,
    this.child,
    this.visual,
    this.accent = false,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<String> highlights;
  final Widget? action;
  final Widget? child;
  final Widget? visual;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = _usesCompactFirstJourneySection(
          context,
          constraints,
        );
        return ExpeditionPanel(
          tone: accent ? ExpeditionPanelTone.energy : ExpeditionPanelTone.lumen,
          padding: EdgeInsets.all(compact ? 16 : 22),
          child: Column(
            key: Key(
              compact
                  ? 'first-journey-panel-compact'
                  : 'first-journey-panel-wide',
            ),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (visual != null)
                visual!
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.86, end: 1),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    builder:
                        (BuildContext context, double scale, Widget? child) =>
                            Transform.scale(scale: scale, child: child),
                    child: CircleAvatar(
                      radius: compact ? 26 : 30,
                      backgroundColor: accent
                          ? colors.primary
                          : colors.secondaryContainer,
                      child: Icon(
                        icon,
                        size: compact ? 27 : 31,
                        color: accent
                            ? colors.onPrimary
                            : colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              SizedBox(height: compact ? 14 : 18),
              Text(
                eyebrow.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(body, style: Theme.of(context).textTheme.bodyLarge),
              if (highlights.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                ...highlights.map(
                  (String text) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.check_circle_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(text)),
                      ],
                    ),
                  ),
                ),
              ],
              if (child != null) ...<Widget>[
                const SizedBox(height: 18),
                child!,
              ],
              if (action != null) ...<Widget>[
                const SizedBox(height: 22),
                action!,
              ],
            ],
          ),
        );
      },
    );
  }
}
