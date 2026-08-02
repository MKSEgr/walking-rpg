import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';

class CachedSnapshotBanner extends StatelessWidget {
  const CachedSnapshotBanner({
    super.key,
    required this.metadata,
    this.title = 'Маршрут доступен только для чтения',
  });

  final CachedReadMetadata metadata;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('cached-snapshot-banner'),
      container: true,
      liveRegion: true,
      child: ExpeditionPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: ExpeditionBadge(
                label: 'Сохранённый маршрут',
                icon: Icons.cloud_off_outlined,
                tone: ExpeditionPanelTone.neutral,
                allowWrap: true,
                accentColor: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              key: const Key('cached-snapshot-heading'),
              container: true,
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Показано сохранённое состояние от '
              '${_format(metadata.cachedAt)}. Изменения временно '
              'недоступны до восстановления связи.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.72),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Почему показана копия',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            metadata.reason,
                            key: const Key('cached-snapshot-reason'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _format(DateTime value) {
    final DateTime local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
