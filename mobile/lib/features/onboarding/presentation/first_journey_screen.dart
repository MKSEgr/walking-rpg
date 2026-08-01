import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/onboarding/domain/first_journey_progress.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/recovery/presentation/mobile_command_recovery_action.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Первый путь'),
        actions: <Widget>[
          MobileCommandRecoveryAction(
            key: const Key('first-journey-recovery'),
            onPressed: onOpenRecovery,
            count: recoveryCount,
            unavailable: recoveryUnavailable,
          ),
          IconButton(
            tooltip: 'Аккаунт',
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
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _JourneyProgressHeader(progress: progress),
                        if (progress.readOnly) ...<Widget>[
                          const SizedBox(height: 12),
                          const _StatusCard(
                            icon: Icons.cloud_off_outlined,
                            text:
                                'Показано сохранённое состояние. Действия '
                                'станут доступны после подключения к серверу.',
                          ),
                        ],
                        if (notice != null) ...<Widget>[
                          const SizedBox(height: 12),
                          _StatusCard(icon: Icons.info_outline, text: notice!),
                        ],
                        if (errorMessage != null) ...<Widget>[
                          const SizedBox(height: 12),
                          _StatusCard(
                            icon: Icons.error_outline,
                            text: errorMessage!,
                            error: true,
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
                          child: const Text('Продолжить позже'),
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

class _JourneyProgressHeader extends StatelessWidget {
  const _JourneyProgressHeader({required this.progress});

  final FirstJourneyProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Маршрут к первому сигналу',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${progress.completedCount}/${FirstJourneyProgress.steps.length}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress.progressValue),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double value, Widget? child) {
            return LinearProgressIndicator(value: value, minHeight: 8);
          },
        ),
      ],
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
      eyebrow: 'Сигнал найден',
      title: 'Твой путь начинается с реальных шагов',
      body:
          'Ты — Навигатор. Прогулки создают ENERGY, ENERGY открывает '
          'узлы экспедиции, а решения меняют награды и связь с питомцем.',
      highlights: const <String>[
        'Ходи сейчас — проходи события, когда удобно.',
        'Сервер считает награды и не доверяет цифрам клиента.',
        'Первая цель подстроится под твою историю активности.',
      ],
      action: FilledButton.icon(
        key: const Key('first-journey-start'),
        onPressed: busy ? null : onContinue,
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Начать путь'),
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
      eyebrow: 'Шаг 1 · движение',
      title: 'Подключи шаги и получи первую ENERGY',
      body:
          'Системный экран запросит доступ только к количеству шагов. '
          'Walking RPG не читает геолокацию, пульс, сон, вес или медицинские записи.',
      highlights: const <String>[
        'Только чтение STEPS.',
        'Повторная синхронизация не выдаёт награду дважды.',
        '100 подтверждённых шагов = 1 ENERGY.',
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
        label: Text(
          busy ? 'Подключаем шаги...' : 'Разрешить и синхронизировать',
        ),
      ),
    );
  }
}

class _ActivityRewardPanel extends StatelessWidget {
  const _ActivityRewardPanel({
    super.key,
    required this.result,
    required this.busy,
    required this.onContinue,
  });

  final ActivitySyncResult result;
  final bool busy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final String reward = result.energyGranted > 0
        ? '+${result.energyGranted} ENERGY'
        : 'Шаги подключены';
    return _JourneyPanel(
      icon: Icons.bolt,
      eyebrow: 'Движение подтверждено',
      title: reward,
      body:
          'Принято ${result.acceptedTotal} шагов. '
          'На балансе ${result.energyBalanceAfter} ENERGY.',
      highlights: <String>[
        if (result.energyGranted == 0)
          'До следующей ENERGY не хватает подтверждённых шагов.'
        else
          'Новая энергия уже доступна для экспедиции.',
        'Риск-проверка: ${result.riskStatus}.',
      ],
      action: FilledButton.icon(
        key: const Key('first-journey-activity-continue'),
        onPressed: busy ? null : onContinue,
        icon: const Icon(Icons.pets_outlined),
        label: const Text('Выбрать питомца'),
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
      eyebrow: 'Шаг 2 · спутник',
      title: 'Кто пойдёт к сигналу вместе с тобой?',
      body:
          'Выбор настоящий: активный питомец появится на главном экране '
          'и будет получать связь за решения событий.',
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
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.64),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.72)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('first-journey-select-${pet.petId}'),
        onTap: busy ? null : onSelect,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              CompanionPortrait(
                key: Key('first-journey-pet-portrait-${pet.petId}'),
                petId: pet.petId,
                name: pet.name,
                species: pet.species,
                evolutionStage: pet.evolutionStage,
                active: pet.active,
                size: 78,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      pet.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        ExpeditionBadge(
                          label: pet.species,
                          icon: Icons.blur_circular,
                        ),
                        ExpeditionBadge(
                          label: 'Форма ${pet.evolutionStage + 1}',
                          icon: Icons.auto_awesome_outlined,
                          tone: pet.evolutionStage > 0
                              ? ExpeditionPanelTone.resonance
                              : ExpeditionPanelTone.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pet.trait,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
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
    return _JourneyPanel(
      icon: Icons.explore_outlined,
      eyebrow: 'Шаг 3 · первый узел',
      title: home.currentNodeName,
      body:
          'Направь ENERGY к внешнему маяку. Можно продвигаться частями: '
          'прогресс и баланс сохраняются на сервере.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${home.expeditionProgress} / ${home.requiredEnergy} ENERGY',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: home.expeditionProgressValue,
            minHeight: 9,
          ),
          const SizedBox(height: 8),
          Text('На балансе ${home.availableEnergy} · до маяка $remaining'),
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
            label: Text(
              canAdvance
                  ? 'Направить ${home.spendableEnergy} ENERGY'
                  : 'Синхронизировать новые шаги',
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
      return const _JourneyPanel(
        icon: Icons.sync_problem_outlined,
        eyebrow: 'Состояние обновляется',
        title: 'Маяк достигнут, но событие ещё не загружено',
        body: 'Повтори загрузку после восстановления соединения.',
      );
    }
    return _JourneyPanel(
      icon: Icons.auto_awesome_outlined,
      eyebrow: 'Шаг 4 · решение',
      title: current.title,
      body: current.summary,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        choice.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(choice.description),
                      const SizedBox(height: 6),
                      Text(
                        '+${choice.pilotExperienceReward} XP · '
                        '+${choice.petBondReward} связь',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
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
    return _JourneyPanel(
      icon: Icons.emoji_events_outlined,
      eyebrow: 'Первый сигнал расшифрован',
      title: result.outcomeTitle,
      body: result.outcomeSummary,
      highlights: <String>[
        '+${result.pilot.experienceGained} XP пилота',
        '+${result.pet.bondGained} связи · ${result.pet.name}',
        if (result.material != null)
          '+${result.material!.quantityGained} ${result.material!.name}',
      ],
      action: FilledButton.icon(
        key: const Key('first-journey-finish'),
        onPressed: busy ? null : onFinish,
        icon: const Icon(Icons.explore),
        label: const Text('Открыть экспедицию'),
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
      eyebrow: 'Первый путь завершён',
      title: 'Экспедиция открыта',
      body:
          'Шаги подключены, питомец выбран, а первый сигнал уже сохранён '
          'в Путевом журнале.',
      action: FilledButton.icon(
        key: const Key('first-journey-finish'),
        onPressed: busy ? null : onFinish,
        icon: const Icon(Icons.explore),
        label: const Text('Открыть экспедицию'),
      ),
      accent: true,
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
    this.accent = false,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<String> highlights;
  final Widget? action;
  final Widget? child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ExpeditionPanel(
      tone: accent ? ExpeditionPanelTone.energy : ExpeditionPanelTone.lumen,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.86, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (BuildContext context, double scale, Widget? child) =>
                  Transform.scale(scale: scale, child: child),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: accent
                    ? colors.primary
                    : colors.secondaryContainer,
                child: Icon(
                  icon,
                  size: 31,
                  color: accent
                      ? colors.onPrimary
                      : colors.onSecondaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
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
          if (child != null) ...<Widget>[const SizedBox(height: 18), child!],
          if (action != null) ...<Widget>[const SizedBox(height: 22), action!],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.text,
    this.error = false,
  });

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      color: error ? colors.errorContainer : colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              color: error
                  ? colors.onErrorContainer
                  : colors.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
