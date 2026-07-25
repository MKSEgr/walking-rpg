import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/widgets/progress_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const snapshot = HomeSnapshot.demo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walking RPG'),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              subtitle: 'Персональная цель будет рассчитана после калибровки.',
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
              children: [
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
              onPressed: null,
              icon: const Icon(Icons.sync),
              label: const Text('Подключить реальные шаги — следующий этап'),
            ),
            const SizedBox(height: 12),
            Text(
              'Доступная энергия: ${snapshot.availableEnergy}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
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
          children: [
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
