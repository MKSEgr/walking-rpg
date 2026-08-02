import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
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
          body: ExpeditionBackdrop(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: <Widget>[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _ValidationHero(snapshot: snapshot),
                          const SizedBox(height: 22),
                          const Semantics(
                            key: Key('validation-launch-heading'),
                            container: true,
                            header: true,
                            child: ExpeditionSectionTitle(
                              title: 'Паспорт запуска',
                              subtitle:
                                  'Точный build, источник данных и режим '
                                  'сессии',
                              icon: Icons.fingerprint,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _LaunchCard(launch: snapshot.launch),
                          const SizedBox(height: 22),
                          const Semantics(
                            key: Key('validation-actions-heading'),
                            container: true,
                            header: true,
                            child: ExpeditionSectionTitle(
                              title: 'Сценарий проверки',
                              subtitle:
                                  'Три явных шага оператора без фоновых '
                                  'действий',
                              icon: Icons.route,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ActionCard(
                            controller: widget.controller,
                            busy: _busy,
                            onRead: () => _run(
                              () => widget.controller.readHealth(
                                activeOwnerId: _activeOwner(),
                              ),
                              successMessage:
                                  'Aggregated daily total зафиксирован.',
                            ),
                            onSync: widget.controller.canSynchronize
                                ? () => _run(
                                    () => widget.controller.synchronize(
                                      activeOwnerId: _activeOwner(),
                                    ),
                                    successMessage:
                                        'Server-authoritative sync '
                                        'зафиксирован.',
                                  )
                                : null,
                            onCheckpoint: () => _run(
                              () => widget.controller
                                  .captureAuthoritativeCheckpoint(
                                    activeOwnerId: _activeOwner(),
                                  ),
                              successMessage:
                                  'Authoritative checkpoint зафиксирован.',
                            ),
                          ),
                          if (snapshot.latestHealth != null ||
                              snapshot.latestSync != null ||
                              snapshot.authoritativeCheckpoint !=
                                  null) ...<Widget>[
                            const SizedBox(height: 22),
                            const Semantics(
                              key: Key('validation-observations-heading'),
                              container: true,
                              header: true,
                              child: ExpeditionSectionTitle(
                                title: 'Принятые наблюдения',
                                subtitle:
                                    'Только факты текущего запуска и свежего '
                                    'ответа сервера',
                                icon: Icons.radar,
                              ),
                            ),
                          ],
                          if (snapshot.latestHealth != null) ...<Widget>[
                            const SizedBox(height: 12),
                            _HealthCard(observation: snapshot.latestHealth!),
                          ],
                          if (snapshot.latestSync != null) ...<Widget>[
                            const SizedBox(height: 12),
                            _SyncCard(observation: snapshot.latestSync!),
                          ],
                          if (snapshot.authoritativeCheckpoint !=
                              null) ...<Widget>[
                            const SizedBox(height: 12),
                            _CheckpointCard(
                              facts: snapshot.authoritativeCheckpoint!,
                            ),
                          ],
                          const SizedBox(height: 22),
                          const Semantics(
                            key: Key('validation-journal-heading'),
                            container: true,
                            header: true,
                            child: ExpeditionSectionTitle(
                              title: 'Журнал запуска',
                              subtitle:
                                  'Последовательность действий без raw '
                                  'payload и identity',
                              icon: Icons.receipt_long_outlined,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _JournalCard(entries: snapshot.journal),
                          const SizedBox(height: 22),
                          const Semantics(
                            key: Key('validation-evidence-heading'),
                            container: true,
                            header: true,
                            child: ExpeditionSectionTitle(
                              title: 'Пакет evidence',
                              subtitle:
                                  'Проверяемый JSON для ручного '
                                  'device-протокола',
                              icon: Icons.verified_user,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ValidationExportPanel(
                            exporting: _exporting,
                            busy: _busy,
                            lastExport: _lastExport,
                            onExport: _export,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

class _ValidationHero extends StatelessWidget {
  const _ValidationHero({required this.snapshot});

  final DeviceValidationEvidenceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final int journalCount = snapshot.journal.length;
    return Semantics(
      key: const Key('validation-center-summary'),
      container: true,
      explicitChildNodes: true,
      label:
          'Validation Center. Внутренний non-release контур. '
          'Записей журнала: $journalCount из 64.',
      child: ExpeditionPanel(
        tone: ExpeditionPanelTone.resonance,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                const ExpeditionBadge(
                  label: 'INTERNAL · NON-RELEASE',
                  icon: Icons.science_outlined,
                  tone: ExpeditionPanelTone.resonance,
                ),
                ExpeditionBadge(
                  label: 'ЖУРНАЛ $journalCount/64',
                  icon: Icons.receipt_long_outlined,
                  tone: ExpeditionPanelTone.lumen,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Проверка реального устройства',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Один контролируемый запуск: Health provider, разрешение, '
              'агрегированный total и свежий authoritative checkpoint.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              key: const Key('validation-safety-note'),
              decoration: BoxDecoration(
                color: palette.resonance.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: palette.resonance.withValues(alpha: 0.34),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.policy_outlined, size: 21),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'JSON не является доказательством physical '
                        'validation без заполненного протокола и review.',
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
}

class _ValidationExportPanel extends StatelessWidget {
  const _ValidationExportPanel({
    required this.exporting,
    required this.busy,
    required this.lastExport,
    required this.onExport,
  });

  final bool exporting;
  final bool busy;
  final ValidationEvidenceExportArtifact? lastExport;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ExpeditionPanel(
      tone: ExpeditionPanelTone.lumen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const ExpeditionSectionTitle(
            title: 'Schema-v1 export',
            subtitle: 'Allowlist, redaction и checksum до передачи файла',
            icon: Icons.data_object,
          ),
          const SizedBox(height: 14),
          const Text(
            'Файл ограничен 64 KiB и удаляется из temporary directory '
            'после share.',
          ),
          if (lastExport != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Последний export: ${lastExport!.fileName}',
              key: const Key('validation-last-export'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            key: const Key('validation-export-button'),
            onPressed: busy ? null : onExport,
            icon: exporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            label: Text(
              exporting
                  ? 'Проверяем и формируем...'
                  : 'Проверить checksum и передать JSON',
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchCard extends StatelessWidget {
  const _LaunchCard({required this.launch});

  final EvidenceLaunchMetadata launch;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ExpeditionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ExpeditionBadge(
                label: launch.buildMode,
                icon: Icons.build_circle,
                tone: ExpeditionPanelTone.neutral,
              ),
              ExpeditionBadge(
                label: launch.authenticationMode,
                icon: Icons.vpn_key_outlined,
                tone: ExpeditionPanelTone.lumen,
              ),
              ExpeditionBadge(
                label: launch.healthSource.wireName,
                icon: Icons.health_and_safety_outlined,
                tone: ExpeditionPanelTone.resonance,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ValidationFact(
            label: 'Устройство',
            value: '${launch.platform} · ${launch.operatingSystemVersion}',
          ),
          const SizedBox(height: 10),
          _ValidationFact(
            label: 'Сборка',
            value: 'App ${launch.appVersion} (${launch.buildNumber})',
          ),
          const SizedBox(height: 14),
          Text(
            'SOURCE GIT SHA',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            launch.sourceGitSha,
            key: const Key('validation-source-sha'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
    return ExpeditionPanel(
      tone: ExpeditionPanelTone.resonance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const ExpeditionSectionTitle(
            title: 'Явные действия оператора',
            subtitle: 'Порядок фиксируется в журнале текущего запуска',
            icon: Icons.touch_app_outlined,
          ),
          const SizedBox(height: 16),
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
            const SizedBox(height: 12),
            const _ValidationWarning(
              message:
                  'Лимит журнала не позволяет записать ещё одно полное '
                  'действие. Экспортируйте текущий JSON.',
            ),
          ],
        ],
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
      icon: Icons.health_and_safety_outlined,
      tone: ExpeditionPanelTone.lumen,
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
      icon: Icons.sync,
      tone: ExpeditionPanelTone.energy,
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
      icon: Icons.fact_check_outlined,
      tone: ExpeditionPanelTone.resonance,
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
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final List<EvidenceJournalEntry> reversedEntries = entries.reversed.toList(
      growable: false,
    );
    return ExpeditionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Журнал · ${entries.length}/64',
            key: const Key('validation-journal-count'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const Text('Действия ещё не выполнялись.')
          else
            for (
              int index = 0;
              index < reversedEntries.length;
              index += 1
            ) ...<Widget>[
              _ValidationJournalEntry(
                entry: reversedEntries[index],
                accent: palette.resonance,
              ),
              if (index < reversedEntries.length - 1) const Divider(height: 20),
            ],
        ],
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({
    required this.title,
    required this.icon,
    required this.tone,
    required this.facts,
  });

  final String title;
  final IconData icon;
  final ExpeditionPanelTone tone;
  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    return ExpeditionPanel(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExpeditionSectionTitle(
            title: title,
            subtitle: 'Зафиксировано в текущем evidence journal',
            icon: icon,
          ),
          const SizedBox(height: 14),
          for (int index = 0; index < facts.length; index += 1) ...<Widget>[
            _ValidationFactLine(fact: facts[index]),
            if (index < facts.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _ValidationJournalEntry extends StatelessWidget {
  const _ValidationJournalEntry({required this.entry, required this.accent});

  final EvidenceJournalEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String details =
        '${entry.outcome.wireName} · ${entry.durationMs} ms'
        '${entry.errorCategory == null ? '' : ' · ${entry.errorCategory!.wireName}'}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.14),
            border: Border.all(color: accent.withValues(alpha: 0.42)),
          ),
          child: SizedBox.square(
            dimension: 34,
            child: Center(
              child: Text(
                '${entry.sequence}',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: accent),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.scenario.wireName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                details,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ValidationFact extends StatelessWidget {
  const _ValidationFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(value),
      ],
    );
  }
}

class _ValidationFactLine extends StatelessWidget {
  const _ValidationFactLine({required this.fact});

  final String fact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary,
            ),
            child: const SizedBox.square(dimension: 5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(fact)),
      ],
    );
  }
}

class _ValidationWarning extends StatelessWidget {
  const _ValidationWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.error.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.warning_amber_rounded, color: colors.error, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(message, style: TextStyle(color: colors.error)),
            ),
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
