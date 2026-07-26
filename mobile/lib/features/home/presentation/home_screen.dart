import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/features/event/data/event_api_client.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/expedition/data/expedition_api_client.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_advance_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/widgets/progress_card.dart';

typedef HomeSnapshotLoader = Future<HomeSnapshot> Function();
typedef ExpeditionAdvancer =
    Future<ExpeditionAdvanceResult> Function({
      required String expeditionId,
      required int energyToSpend,
      required String idempotencyKey,
    });
typedef EventResolver =
    Future<EventResolutionResult> Function({
      required String eventId,
      required String choiceId,
      required String idempotencyKey,
    });
typedef IdempotencyKeyFactory = String Function();

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.loader,
    this.advancer,
    this.eventResolver,
    this.idempotencyKeyFactory,
  });

  final HomeSnapshotLoader? loader;
  final ExpeditionAdvancer? advancer;
  final EventResolver? eventResolver;
  final IdempotencyKeyFactory? idempotencyKeyFactory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeSnapshot> _snapshotFuture;
  bool _isAdvancing = false;
  bool _isResolving = false;

  bool get _isBusy => _isAdvancing || _isResolving;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader) {
      _snapshotFuture = _loadSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walking RPG'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Обновить',
            onPressed: _isBusy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Настройки',
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<HomeSnapshot>(
          future: _snapshotFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<HomeSnapshot> asyncSnapshot,
              ) {
                if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (asyncSnapshot.hasError) {
                  return _HomeError(
                    error: asyncSnapshot.error!,
                    onRetry: _reload,
                    onOpenDemo: _openDemo,
                  );
                }
                final HomeSnapshot? snapshot = asyncSnapshot.data;
                if (snapshot == null) {
                  return _HomeError(
                    error: const FormatException('Backend не вернул состояние'),
                    onRetry: _reload,
                    onOpenDemo: _openDemo,
                  );
                }
                return _HomeBody(
                  snapshot: snapshot,
                  isAdvancing: _isAdvancing,
                  isResolving: _isResolving,
                  onAdvance: () => _advance(snapshot),
                  onResolve: (HomeEventChoice choice) =>
                      _resolveEvent(snapshot, choice),
                  onRefresh: _reload,
                );
              },
        ),
      ),
    );
  }

  Future<HomeSnapshot> _loadSnapshot() {
    final HomeSnapshotLoader? loader = widget.loader;
    if (loader != null) {
      return loader();
    }
    return HomeApiClient.fromEnvironment().fetchHome(DateTime.now());
  }

  Future<void> _advance(HomeSnapshot snapshot) async {
    final int energyToSpend = snapshot.spendableEnergy;
    if (_isBusy || energyToSpend <= 0) {
      return;
    }

    setState(() {
      _isAdvancing = true;
    });
    try {
      final ExpeditionAdvancer advancer =
          widget.advancer ?? ExpeditionApiClient.fromEnvironment().advance;
      final String idempotencyKey = _nextKey(snapshot.expeditionId);
      final ExpeditionAdvanceResult result = await advancer(
        expeditionId: snapshot.expeditionId,
        energyToSpend: energyToSpend,
        idempotencyKey: idempotencyKey,
      );
      if (!mounted) {
        return;
      }
      final String message = result.unlockedEvent == null
          ? 'Экспедиция продвинулась на ${result.energySpent} энергии'
          : 'Открыто событие: ${result.unlockedEvent!.title}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _snapshotFuture = _loadSnapshot();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось продвинуть экспедицию: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdvancing = false;
        });
      }
    }
  }

  Future<void> _resolveEvent(
    HomeSnapshot snapshot,
    HomeEventChoice choice,
  ) async {
    final HomeExpeditionEvent? event = snapshot.unlockedEvent;
    if (_isBusy || event == null || event.isResolved) {
      return;
    }

    setState(() {
      _isResolving = true;
    });
    try {
      final EventResolver resolver =
          widget.eventResolver ?? EventApiClient.fromEnvironment().resolve;
      final EventResolutionResult result = await resolver(
        eventId: event.eventId,
        choiceId: choice.choiceId,
        idempotencyKey: _nextKey(event.eventId),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.outcomeTitle}: +${result.pilot.experienceGained} XP, '
            '+${result.pet.bondGained} связь',
          ),
        ),
      );
      setState(() {
        _snapshotFuture = _loadSnapshot();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось разрешить событие: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  String _nextKey(String sourceId) {
    return widget.idempotencyKeyFactory?.call() ??
        '$sourceId-${DateTime.now().microsecondsSinceEpoch}';
  }

  void _openDemo() {
    setState(() {
      _snapshotFuture = Future<HomeSnapshot>.value(HomeSnapshot.demo);
    });
  }

  void _reload() {
    if (_isBusy) {
      return;
    }
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.snapshot,
    required this.isAdvancing,
    required this.isResolving,
    required this.onAdvance,
    required this.onResolve,
    required this.onRefresh,
  });

  final HomeSnapshot snapshot;
  final bool isAdvancing;
  final bool isResolving;
  final VoidCallback onAdvance;
  final ValueChanged<HomeEventChoice> onResolve;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final String lastSync = snapshot.lastActivitySyncAt == null
        ? 'Шаги ещё не синхронизированы'
        : 'Последняя синхронизация: ${snapshot.lastActivitySyncAt}';
    final HomeExpeditionEvent? event = snapshot.unlockedEvent;
    final bool eventReady = event?.status == 'READY';
    final bool completed = snapshot.expeditionStatus == 'COMPLETED';
    final int spendableEnergy = snapshot.spendableEnergy;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          completed
              ? 'Первая экспедиция завершена'
              : 'Экспедиция ждёт твоих шагов',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Сначала прогулка. Решения и награды — после неё.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        ProgressCard(
          title: 'Сегодня: ${snapshot.dailySteps} / ${snapshot.dailyGoal}',
          subtitle: lastSync,
          progress: snapshot.dailyProgress,
          icon: Icons.directions_walk,
        ),
        ProgressCard(
          title: snapshot.expeditionName,
          subtitle:
              '${snapshot.expeditionProgress} / ${snapshot.requiredEnergy} энергии'
              ' · ${snapshot.currentNodeName}',
          progress: snapshot.expeditionProgressValue,
          icon: Icons.explore_outlined,
        ),
        if (event != null) ...<Widget>[
          const SizedBox(height: 4),
          _EventCard(
            event: event,
            isResolving: isResolving,
            onChoose: onResolve,
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: _CharacterCard(
                label: 'Пилот',
                name: snapshot.pilotName,
                level: snapshot.pilotLevel,
                detail:
                    'XP ${snapshot.pilotCurrentExperience} / ${snapshot.pilotNextLevelExperience}',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CharacterCard(
                label: 'Питомец',
                name: snapshot.petName,
                level: snapshot.petLevel,
                detail: 'Связь ${snapshot.petBond}',
                icon: Icons.pets_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed:
              eventReady ||
                  completed ||
                  spendableEnergy <= 0 ||
                  isAdvancing ||
                  isResolving
              ? null
              : onAdvance,
          icon: isAdvancing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.rocket_launch_outlined),
          label: Text(
            completed
                ? 'Экспедиция завершена'
                : eventReady
                ? 'Выберите решение события'
                : spendableEnergy > 0
                ? 'Потратить $spendableEnergy энергии'
                : 'Нужно накопить энергию',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isAdvancing || isResolving ? null : onRefresh,
          icon: const Icon(Icons.sync),
          label: const Text('Обновить состояние'),
        ),
        const SizedBox(height: 12),
        Text(
          'Доступная энергия: ${snapshot.availableEnergy} '
          '· версия ${snapshot.economyVersion}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Экспедиция: версия ${snapshot.expeditionVersion} '
          '· ${snapshot.expeditionStatus}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Контент: ${snapshot.contentVersion}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isResolving,
    required this.onChoose,
  });

  final HomeExpeditionEvent event;
  final bool isResolving;
  final ValueChanged<HomeEventChoice> onChoose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.auto_awesome_outlined, size: 32),
            const SizedBox(height: 10),
            Text(
              event.isResolved ? 'Событие разрешено' : 'Событие открыто',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(event.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(event.summary),
            if (event.isResolved) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                event.selectedChoiceTitle ?? 'Выбор зафиксирован',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                event.outcomeTitle ?? 'Результат события',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(event.outcomeSummary ?? ''),
            ] else ...<Widget>[
              const SizedBox(height: 12),
              for (final HomeEventChoice choice in event.choices) ...<Widget>[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: isResolving ? null : () => onChoose(choice),
                    child: Column(
                      children: <Widget>[
                        Text(choice.title),
                        Text(
                          '+${choice.pilotExperienceReward} XP · '
                          '+${choice.petBondReward} связь',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(choice.description),
                const SizedBox(height: 8),
              ],
              if (isResolving) const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({
    required this.error,
    required this.onRetry,
    required this.onOpenDemo,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onOpenDemo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'Не удалось загрузить состояние',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
            TextButton(
              onPressed: onOpenDemo,
              child: const Text('Открыть демонстрационное состояние'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.label,
    required this.name,
    required this.level,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String name;
  final int level;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 32),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Уровень $level'),
            const SizedBox(height: 2),
            Text(detail),
          ],
        ),
      ),
    );
  }
}
