import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/widgets/progress_card.dart';

typedef HomeSnapshotLoader = Future<HomeSnapshot> Function();

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.loader,
  });

  final HomeSnapshotLoader? loader;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeSnapshot> _snapshotFuture;

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
            onPressed: _reload,
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
          builder: (
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
            return _HomeBody(snapshot: snapshot, onRefresh: _reload);
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

  void _openDemo() {
    setState(() {
      _snapshotFuture = Future<HomeSnapshot>.value(HomeSnapshot.demo);
    });
  }

  void _reload() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.snapshot,
    required this.onRefresh,
  });

  final HomeSnapshot snapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final String lastSync = snapshot.lastActivitySyncAt == null
        ? 'Шаги ещё не синхронизированы'
        : 'Последняя синхронизация: ${snapshot.lastActivitySyncAt}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Экспедиция ждёт твоих шагов',
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
              '${snapshot.expeditionProgress} / ${snapshot.requiredEnergy} энергии',
          progress: snapshot.expeditionProgressValue,
          icon: Icons.explore_outlined,
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: _CharacterCard(
                label: 'Пилот',
                name: snapshot.pilotName,
                level: snapshot.pilotLevel,
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CharacterCard(
                label: 'Питомец',
                name: snapshot.petName,
                level: snapshot.petLevel,
                icon: Icons.pets_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onRefresh,
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
          'Контент: ${snapshot.contentVersion}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
    required this.icon,
  });

  final String label;
  final String name;
  final int level;
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
          ],
        ),
      ),
    );
  }
}
