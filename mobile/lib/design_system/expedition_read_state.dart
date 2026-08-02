import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';

enum _ExpeditionReadStateKind { loading, failure }

class ExpeditionReadState extends StatelessWidget {
  const ExpeditionReadState.loading({
    super.key,
    required this.title,
    required this.message,
  }) : _kind = _ExpeditionReadStateKind.loading,
       details = null,
       primaryActionKey = null,
       primaryActionLabel = null,
       onPrimaryAction = null,
       secondaryActionKey = null,
       secondaryActionLabel = null,
       onSecondaryAction = null;

  const ExpeditionReadState.failure({
    super.key,
    required this.title,
    required this.message,
    required this.details,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.primaryActionKey,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.secondaryActionKey,
  }) : _kind = _ExpeditionReadStateKind.failure,
       assert(
         (secondaryActionLabel == null) == (onSecondaryAction == null),
         'Secondary action label and callback must be supplied together',
       );

  final _ExpeditionReadStateKind _kind;
  final String title;
  final String message;
  final String? details;
  final Key? primaryActionKey;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final Key? secondaryActionKey;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  bool get _loading => _kind == _ExpeditionReadStateKind.loading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String statusLabel = _loading
        ? 'Связь с маршрутом'
        : 'Сигнал недоступен';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: '$statusLabel. $title. $message',
              liveRegion: true,
              child: ExpeditionPanel(
                tone: _loading
                    ? ExpeditionPanelTone.lumen
                    : ExpeditionPanelTone.neutral,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ExpeditionBadge(
                        label: statusLabel,
                        icon: _loading ? Icons.radar : Icons.cloud_off_outlined,
                        tone: _loading
                            ? ExpeditionPanelTone.lumen
                            : ExpeditionPanelTone.neutral,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Align(child: _ReadStateSignal(loading: _loading)),
                    const SizedBox(height: 20),
                    Semantics(
                      key: const Key('expedition-read-state-heading'),
                      container: true,
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (details case final String details
                        when details.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: 0.62,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            details,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                    if (primaryActionLabel case final String label) ...<Widget>[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: primaryActionKey,
                          onPressed: onPrimaryAction,
                          icon: const Icon(Icons.refresh),
                          label: Text(label),
                        ),
                      ),
                    ],
                    if (secondaryActionLabel
                        case final String label) ...<Widget>[
                      const SizedBox(height: 4),
                      TextButton(
                        key: secondaryActionKey,
                        onPressed: onSecondaryAction,
                        child: Text(label),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadStateSignal extends StatelessWidget {
  const _ReadStateSignal({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = loading ? colors.primary : colors.error;
    return Semantics(
      label: loading ? 'Получение актуального состояния' : 'Связь потеряна',
      child: SizedBox.square(
        dimension: 72,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (loading)
              CircularProgressIndicator(
                strokeWidth: 3,
                color: accent,
                backgroundColor: colors.surfaceContainerHighest,
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.52)),
                ),
              ),
            Center(
              child: Icon(
                loading ? Icons.radar : Icons.cloud_off_outlined,
                color: accent,
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
