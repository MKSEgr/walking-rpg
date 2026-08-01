import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/features/validation/application/validation_evidence_controller.dart';
import 'package:walking_rpg_mobile/features/validation/application/validation_evidence_exporter.dart';
import 'package:walking_rpg_mobile/features/validation/domain/device_validation_evidence.dart';

class ValidationCenterScreen extends StatefulWidget {
  const ValidationCenterScreen({
    super.key,
    required this.controller,
    required this.activeOwnerProvider,
    this.exporter,
  });

  final ValidationEvidenceController controller;
  final ValidationOwnerProvider activeOwnerProvider;
  final ValidationEvidenceExportService? exporter;

  @override
  State<ValidationCenterScreen> createState() => _ValidationCenterScreenState();
}

class _ValidationCenterScreenState extends State<ValidationCenterScreen> {
  ValidationEvidenceExportArtifact? _lastExport;
  bool _exporting = false;

  bool get _busy => widget.controller.busy || _exporting;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final DeviceValidationEvidenceSnapshot snapshot =
            widget.controller.snapshot;
        return Scaffold(
          appBar: AppBar(title: const Text('Validation Center')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Внутренний non-release инструмент. JSON не является '
                      'доказательством physical validation без заполненного '
                      'протокола и review.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _LaunchCard(launch: snapshot.launch),
                const SizedBox(height: 12),
                _ActionCard(
                  controller: widget.controller,
                  busy: _busy,
                  onRead: () => _run(
                    () => widget.controller.readHealth(
                      activeOwnerId: _activeOwner(),
                    ),
                    successMessage: 'Aggregated daily total зафиксирован.',
                  ),
                  onSync: widget.controller.canSynchronize
                      ? () => _run(
                          () => widget.controller.synchronize(
                            activeOwnerId: _activeOwner(),
                          ),
                          successMessage:
                              'Server-authoritative sync зафиксирован.',
                        )
                      : null,
                  onCheckpoint: () => _run(
                    () => widget.controller.captureAuthoritativeCheckpoint(
                      activeOwnerId: _activeOwner(),
                    ),
                    successMessage: 'Authoritative checkpoint зафиксирован.',
                  ),
                ),
                if (snapshot.latestHealth != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _HealthCard(observation: snapshot.latestHealth!),
                ],
                if (snapshot.latestSync != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _SyncCard(observation: snapshot.latestSync!),
                ],
                if (snapshot.authoritativeCheckpoint != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _CheckpointCard(facts: snapshot.authoritativeCheckpoint!),
                ],
                const SizedBox(height: 12),
                _JournalCard(entries: snapshot.journal),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Schema-v1 export',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Файл ограничен 64 KiB, проверяется по allowlist и '
                          'удаляется из temporary directory после share.',
                        ),
                        if (_lastExport != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'Последний export: ${_lastExport!.fileName}',
                            key: const Key('validation-last-export'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          key: const Key('validation-export-button'),
                          onPressed: _busy ? null : _export,
                          icon: _exporting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.ios_share),
                          label: Text(
                            _exporting
                                ? 'Проверяем и формируем...'
                                : 'Проверить checksum и передать JSON',
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
      },
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on Object catch (error) {
      _showError(_validationMessage(error));
    }
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
    });
    try {
      final String activeOwnerId = _activeOwner();
      final String encoded = widget.controller.encode(
        activeOwnerId: activeOwnerId,
      );
      final ValidationEvidenceExportService exporter =
          widget.exporter ?? ValidationEvidenceExporter.fromEnvironment();
      final ValidationEvidenceExportArtifact artifact = await exporter
          .saveAndShare(
            encoded,
            sharePositionOrigin: _shareOrigin(),
            beforeShare: () {
              if (!mounted) {
                throw const ValidationOwnerMismatchException();
              }
              widget.controller.ensureActiveOwner(
                activeOwnerId: _activeOwner(),
              );
            },
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _lastExport = artifact;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Evidence готово: ${artifact.fileName}')),
      );
    } on Object catch (error) {
      _showError(_validationMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  String _activeOwner() {
    final String? owner = widget.activeOwnerProvider();
    if (owner == null || owner.isEmpty) {
      throw const ValidationOwnerMismatchException();
    }
    return owner;
  }

  Rect? _shareOrigin() {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LaunchCard extends StatelessWidget {
  const _LaunchCard({required this.launch});

  final EvidenceLaunchMetadata launch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Запуск', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${launch.platform} · ${launch.operatingSystemVersion}'),
            Text('App ${launch.appVersion} (${launch.buildNumber})'),
            Text('Mode: ${launch.buildMode} · ${launch.authenticationMode}'),
            Text('Health source: ${launch.healthSource.wireName}'),
            const SizedBox(height: 8),
            SelectableText(
              launch.sourceGitSha,
              key: const Key('validation-source-sha'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.controller,
    required this.busy,
    required this.onRead,
    required this.onSync,
    required this.onCheckpoint,
  });

  final ValidationEvidenceController controller;
  final bool busy;
  final VoidCallback onRead;
  final VoidCallback? onSync;
  final VoidCallback onCheckpoint;

  @override
  Widget build(BuildContext context) {
    final bool disabled = busy || controller.journalFull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Явные действия оператора',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const Key('validation-read-button'),
              onPressed: disabled ? null : onRead,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Проверить provider, permission и шаги'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const Key('validation-sync-button'),
              onPressed: disabled ? null : onSync,
              icon: const Icon(Icons.sync),
              label: const Text('Отправить сохранённый total'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const Key('validation-checkpoint-button'),
              onPressed: disabled ? null : onCheckpoint,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Снять authoritative checkpoint'),
            ),
            if (controller.journalFull) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Лимит журнала не позволяет записать ещё одно полное '
                'действие. Экспортируйте текущий JSON.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.observation});

  final EvidenceHealthObservation observation;

  @override
  Widget build(BuildContext context) {
    return _FactsCard(
      title: 'Health observation',
      facts: <String>[
        'Status: ${observation.status.wireName}',
        'Provider: ${observation.providerState.wireName}',
        'Permission: ${observation.permissionState.wireName}',
        if (observation.authoritativeTotal != null)
          'Aggregated total: ${observation.authoritativeTotal}',
        if (observation.localDate != null)
          'Local date: ${observation.localDate}',
        if (observation.timeZone != null) 'Timezone: ${observation.timeZone}',
        'Duration: ${observation.durationMs} ms',
        if (observation.errorCategory != null)
          'Category: ${observation.errorCategory!.wireName}',
      ],
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.observation});

  final EvidenceSyncObservation observation;

  @override
  Widget build(BuildContext context) {
    return _FactsCard(
      title: 'Server sync',
      facts: <String>[
        'Status: ${observation.status.wireName}',
        if (observation.acceptedTotal != null)
          'Accepted: ${observation.acceptedTotal} '
              '(delta ${observation.acceptedDelta})',
        if (observation.energyGranted != null)
          'ENERGY: +${observation.energyGranted} '
              '(balance ${observation.energyBalanceAfter})',
        if (observation.riskStatus != null) 'Risk: ${observation.riskStatus}',
        'Duration: ${observation.durationMs} ms',
        if (observation.errorCategory != null)
          'Category: ${observation.errorCategory!.wireName}',
      ],
    );
  }
}

class _CheckpointCard extends StatelessWidget {
  const _CheckpointCard({required this.facts});

  final AuthoritativeJourneyFacts facts;

  @override
  Widget build(BuildContext context) {
    return _FactsCard(
      title: 'Authoritative checkpoint',
      facts: <String>[
        'Daily steps: ${facts.dailySteps} / ${facts.dailyGoal}',
        'Accepted total: ${facts.totalAcceptedSteps}',
        'ENERGY balance: ${facts.availableEnergy}',
        'Node: ${facts.currentNodeId} · ${facts.expeditionStatus}',
        'First journey: ${facts.firstJourneyStage} '
            '(${facts.completedMilestones.length}/6)',
        'Duration: ${facts.durationMs} ms',
      ],
    );
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.entries});

  final List<EvidenceJournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Журнал · ${entries.length}/64',
              key: const Key('validation-journal-count'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('Действия ещё не выполнялись.')
            else
              for (final EvidenceJournalEntry entry in entries.reversed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${entry.sequence}'),
                  ),
                  title: Text(entry.scenario.wireName),
                  subtitle: Text(
                    '${entry.outcome.wireName} · ${entry.durationMs} ms'
                    '${entry.errorCategory == null ? '' : ' · ${entry.errorCategory!.wireName}'}',
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.title, required this.facts});

  final String title;
  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final String fact in facts) Text(fact),
          ],
        ),
      ),
    );
  }
}

String _validationMessage(Object error) {
  if (error is ValidationOwnerMismatchException) {
    return 'Сессия владельца изменилась. Validation Center закрыт.';
  }
  if (error is EvidenceLimitException) {
    return 'Evidence достигло безопасного лимита. Экспортируйте текущий JSON.';
  }
  if (error is ValidationActionException) {
    return switch (error.category) {
      EvidenceErrorCategory.unsupportedPlatform =>
        'Health source недоступен на этой платформе.',
      EvidenceErrorCategory.providerUpdateRequired =>
        'Health Connect нужно установить или обновить.',
      EvidenceErrorCategory.providerUnavailable =>
        'Health provider недоступен.',
      EvidenceErrorCategory.permissionDenied =>
        'Permission request завершился отказом.',
      EvidenceErrorCategory.permissionSettingsRequired =>
        'Разрешение нужно включить в системных настройках.',
      EvidenceErrorCategory.permissionRestricted =>
        'Разрешение ограничено операционной системой.',
      EvidenceErrorCategory.protectedDataUnavailable =>
        'Health data недоступны, пока устройство заблокировано.',
      EvidenceErrorCategory.timeZoneUnavailable =>
        'ОС не вернула корректную IANA timezone.',
      EvidenceErrorCategory.healthReadFailed =>
        'Не удалось прочитать aggregated daily total.',
      EvidenceErrorCategory.readingRequired =>
        'Сначала выполните Health read в этом запуске.',
      EvidenceErrorCategory.networkUnavailable =>
        'Backend недоступен; checkpoint отмечен как failed.',
      EvidenceErrorCategory.reauthenticationRequired =>
        'Сессия требует повторной аутентификации.',
      EvidenceErrorCategory.cachedSnapshot =>
        'Cached state не принят как authoritative checkpoint.',
      EvidenceErrorCategory.invalidResponse =>
        'Backend вернул ответ вне ожидаемого контракта.',
      EvidenceErrorCategory.journalLimitReached =>
        'Journal достиг безопасного лимита.',
      EvidenceErrorCategory.unexpectedFailure =>
        'Действие завершилось нормализованной internal failure.',
    };
  }
  if (error is FormatException) {
    return 'Evidence не прошло schema/redaction/checksum validation.';
  }
  return 'Не удалось выполнить validation action.';
}
