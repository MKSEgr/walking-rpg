import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/validation/application/validation_evidence_controller.dart';
import 'package:walking_rpg_mobile/features/validation/application/validation_evidence_exporter.dart';
import 'package:walking_rpg_mobile/features/validation/domain/device_validation_evidence.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

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
          appBar: AppBar(title: Text(context.l10n.validationCenterTitle)),
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
                          Semantics(
                            key: const Key('validation-launch-heading'),
                            container: true,
                            header: true,
                            child: ExpeditionSectionTitle(
                              title: context.l10n.validationLaunchTitle,
                              subtitle: context.l10n.validationLaunchSubtitle,
                              icon: Icons.fingerprint,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _LaunchCard(launch: snapshot.launch),
                          const SizedBox(height: 22),
                          Semantics(
                            key: const Key('validation-actions-heading'),
                            container: true,
                            header: true,
                            child: ExpeditionSectionTitle(
                              title: context.l10n.validationScenarioTitle,
                              subtitle: context.l10n.validationScenarioSubtitle,
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
                                  context.l10n.validationHealthSuccess,
                            ),
                            onSync: widget.controller.canSynchronize
                                ? () => _run(
                                    () => widget.controller.synchronize(
                                      activeOwnerId: _activeOwner(),
                                    ),
                                    successMessage:
                                        context.l10n.validationSyncSuccess,
                                  )
                                : null,
                            onCheckpoint: () => _run(
                              () => widget.controller
                                  .captureAuthoritativeCheckpoint(
                                    activeOwnerId: _activeOwner(),
                                  ),
                              successMessage:
                                  context.l10n.validationCheckpointSuccess,
                            ),
                          ),
                          if (snapshot.latestHealth != null ||
                              snapshot.latestSync != null ||
                              snapshot.authoritativeCheckpoint !=
                                  null) ...<Widget>[
                            const SizedBox(height: 22),
                            Semantics(
                              key: const Key('validation-observations-heading'),
                              container: true,
                              header: true,
                              child: ExpeditionSectionTitle(
                                title: context.l10n.validationObservationsTitle,
                                subtitle:
                                    context.l10n.validationObservationsSubtitle,
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
                          Semantics(
                            key: const Key('validation-journal-heading'),
                            container: true,
                            header: true,
                            child: ExpeditionSectionTitle(
                              title: context.l10n.validationJournalSectionTitle,
                              subtitle:
                                  context.l10n.validationJournalSectionSubtitle,
                              icon: Icons.receipt_long_outlined,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _JournalCard(entries: snapshot.journal),
                          const SizedBox(height: 22),
                          Semantics(
                            key: const Key('validation-evidence-heading'),
                            container: true,
                            header: true,
                            child: ExpeditionSectionTitle(
                              title:
                                  context.l10n.validationEvidenceSectionTitle,
                              subtitle: context
                                  .l10n
                                  .validationEvidenceSectionSubtitle,
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
      _showError(_validationMessage(context.l10n, error));
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
        SnackBar(
          content: Text(
            context.l10n.validationEvidenceReady(artifact.fileName),
          ),
        ),
      );
    } on Object catch (error) {
      _showError(_validationMessage(context.l10n, error));
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
      label: context.l10n.validationHeroSemantics(journalCount, 64),
      child: ExpeditionPanel(
        tone: ExpeditionPanelTone.resonance,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ExpeditionBadge(
                  label: context.l10n.validationInternalBadge,
                  icon: Icons.science_outlined,
                  tone: ExpeditionPanelTone.resonance,
                ),
                ExpeditionBadge(
                  label: context.l10n.validationJournalBadge(journalCount, 64),
                  icon: Icons.receipt_long_outlined,
                  tone: ExpeditionPanelTone.lumen,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.validationHeroTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.validationHeroMessage,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            ExcludeSemantics(
              child: _ValidationOperatorRoute(snapshot: snapshot),
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
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.policy_outlined, size: 21),
                    const SizedBox(width: 10),
                    Expanded(child: Text(context.l10n.validationSafetyNote)),
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

class _ValidationOperatorRoute extends StatelessWidget {
  const _ValidationOperatorRoute({required this.snapshot});

  final DeviceValidationEvidenceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color idle = colors.onSurfaceVariant;
    final int healthIndex = snapshot.journal.lastIndexWhere(
      (EvidenceJournalEntry entry) =>
          entry.scenario == EvidenceScenario.provider ||
          entry.scenario == EvidenceScenario.permission ||
          entry.scenario == EvidenceScenario.read,
    );
    final int syncIndex = snapshot.journal.lastIndexWhere(
      (EvidenceJournalEntry entry) => entry.scenario == EvidenceScenario.sync,
    );
    final int checkpointIndex = snapshot.journal.lastIndexWhere(
      (EvidenceJournalEntry entry) =>
          entry.scenario == EvidenceScenario.checkpoint,
    );
    final bool healthComplete =
        snapshot.latestHealth?.status == EvidenceObservationStatus.succeeded &&
        healthIndex >= 0 &&
        snapshot.journal[healthIndex].scenario == EvidenceScenario.read &&
        snapshot.journal[healthIndex].outcome == EvidenceOutcome.passed;
    final bool syncComplete =
        healthComplete &&
        snapshot.latestSync?.status == EvidenceObservationStatus.succeeded &&
        syncIndex > healthIndex &&
        snapshot.journal[syncIndex].outcome == EvidenceOutcome.passed;
    final bool checkpointComplete =
        syncComplete &&
        snapshot.authoritativeCheckpoint != null &&
        checkpointIndex > syncIndex &&
        snapshot.journal[checkpointIndex].outcome == EvidenceOutcome.passed;

    return DecoratedBox(
      key: const Key('validation-operator-route'),
      decoration: BoxDecoration(
        color: palette.resonance.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.resonance.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: <Widget>[
            _ValidationRouteNode(
              key: Key(
                healthComplete
                    ? 'validation-route-health-complete'
                    : 'validation-route-health-pending',
              ),
              icon: Icons.health_and_safety_outlined,
              color: healthComplete ? colors.primary : idle,
              complete: healthComplete,
            ),
            _ValidationRouteConnector(
              active: healthComplete,
              color: colors.primary,
            ),
            _ValidationRouteNode(
              key: Key(
                syncComplete
                    ? 'validation-route-sync-complete'
                    : 'validation-route-sync-pending',
              ),
              icon: Icons.sync,
              color: syncComplete ? palette.energy : idle,
              complete: syncComplete,
            ),
            _ValidationRouteConnector(
              active: syncComplete,
              color: palette.energy,
            ),
            _ValidationRouteNode(
              key: Key(
                checkpointComplete
                    ? 'validation-route-checkpoint-complete'
                    : 'validation-route-checkpoint-pending',
              ),
              icon: Icons.fact_check_outlined,
              color: checkpointComplete ? palette.resonance : idle,
              complete: checkpointComplete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationRouteNode extends StatelessWidget {
  const _ValidationRouteNode({
    super.key,
    required this.icon,
    required this.color,
    required this.complete,
  });

  final IconData icon;
  final Color color;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: complete ? 0.18 : 0.08),
        border: Border.all(
          color: color.withValues(alpha: complete ? 0.72 : 0.28),
          width: complete ? 1.5 : 1,
        ),
        boxShadow: complete
            ? <BoxShadow>[
                BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12),
              ]
            : null,
      ),
      child: SizedBox.square(
        dimension: 42,
        child: Icon(icon, color: color, size: 21),
      ),
    );
  }
}

class _ValidationRouteConnector extends StatelessWidget {
  const _ValidationRouteConnector({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Color idle = Theme.of(context).colorScheme.outlineVariant;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: active
                  ? <Color>[
                      color.withValues(alpha: 0.35),
                      color.withValues(alpha: 0.9),
                    ]
                  : <Color>[
                      idle.withValues(alpha: 0.35),
                      idle.withValues(alpha: 0.65),
                    ],
            ),
          ),
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
          ExpeditionSectionTitle(
            title: context.l10n.validationExportTitle,
            subtitle: context.l10n.validationExportSubtitle,
            icon: Icons.data_object,
          ),
          const SizedBox(height: 14),
          Text(context.l10n.validationExportMessage),
          if (lastExport != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              context.l10n.validationLastExport(lastExport!.fileName),
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
                  ? context.l10n.validationExporting
                  : context.l10n.validationExportAction,
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
            label: context.l10n.validationDeviceLabel,
            value: '${launch.platform} · ${launch.operatingSystemVersion}',
          ),
          const SizedBox(height: 10),
          _ValidationFact(
            label: context.l10n.validationBuildLabel,
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
          ExpeditionSectionTitle(
            title: context.l10n.validationOperatorActionsTitle,
            subtitle: context.l10n.validationOperatorActionsSubtitle,
            icon: Icons.touch_app_outlined,
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            key: const Key('validation-read-button'),
            onPressed: disabled ? null : onRead,
            icon: const Icon(Icons.health_and_safety_outlined),
            label: Text(context.l10n.validationReadAction),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('validation-sync-button'),
            onPressed: disabled ? null : onSync,
            icon: const Icon(Icons.sync),
            label: Text(context.l10n.validationSyncAction),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('validation-checkpoint-button'),
            onPressed: disabled ? null : onCheckpoint,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(context.l10n.validationCheckpointAction),
          ),
          if (controller.journalFull) ...<Widget>[
            const SizedBox(height: 12),
            _ValidationWarning(
              message: context.l10n.validationJournalFullWarning,
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
      title: context.l10n.validationHealthObservationTitle,
      icon: Icons.health_and_safety_outlined,
      tone: ExpeditionPanelTone.lumen,
      facts: <String>[
        context.l10n.validationFactStatus(observation.status.wireName),
        context.l10n.validationFactProvider(observation.providerState.wireName),
        context.l10n.validationFactPermission(
          observation.permissionState.wireName,
        ),
        if (observation.authoritativeTotal != null)
          context.l10n.validationFactAggregatedTotal(
            observation.authoritativeTotal!,
          ),
        if (observation.localDate != null)
          context.l10n.validationFactLocalDate(observation.localDate!),
        if (observation.timeZone != null)
          context.l10n.validationFactTimeZone(observation.timeZone!),
        context.l10n.validationFactDuration(observation.durationMs),
        if (observation.errorCategory != null)
          context.l10n.validationFactCategory(
            observation.errorCategory!.wireName,
          ),
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
      title: context.l10n.validationServerSyncTitle,
      icon: Icons.sync,
      tone: ExpeditionPanelTone.energy,
      facts: <String>[
        context.l10n.validationFactStatus(observation.status.wireName),
        if (observation.acceptedTotal != null)
          context.l10n.validationFactAccepted(
            observation.acceptedTotal!,
            observation.acceptedDelta!,
          ),
        if (observation.energyGranted != null)
          context.l10n.validationFactEnergy(
            observation.energyGranted!,
            observation.energyBalanceAfter!,
          ),
        if (observation.riskStatus != null)
          context.l10n.validationFactRisk(observation.riskStatus!),
        context.l10n.validationFactDuration(observation.durationMs),
        if (observation.errorCategory != null)
          context.l10n.validationFactCategory(
            observation.errorCategory!.wireName,
          ),
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
      title: context.l10n.validationAuthoritativeCheckpointTitle,
      icon: Icons.fact_check_outlined,
      tone: ExpeditionPanelTone.resonance,
      facts: <String>[
        context.l10n.validationFactDailySteps(
          facts.dailySteps,
          facts.dailyGoal,
        ),
        context.l10n.validationFactAcceptedTotal(facts.totalAcceptedSteps),
        context.l10n.validationFactEnergyBalance(facts.availableEnergy),
        context.l10n.validationFactNode(
          facts.currentNodeId,
          facts.expeditionStatus,
        ),
        context.l10n.validationFactFirstJourney(
          facts.firstJourneyStage,
          facts.completedMilestones.length,
          6,
        ),
        context.l10n.validationFactDuration(facts.durationMs),
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
            context.l10n.validationJournalCount(entries.length, 64),
            key: const Key('validation-journal-count'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(context.l10n.validationJournalEmpty)
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
            subtitle: context.l10n.validationFactsSubtitle,
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

String _validationMessage(AppLocalizations l10n, Object error) {
  if (error is ValidationOwnerMismatchException) {
    return l10n.validationErrorOwnerChanged;
  }
  if (error is EvidenceLimitException) {
    return l10n.validationErrorEvidenceLimit;
  }
  if (error is ValidationActionException) {
    return switch (error.category) {
      EvidenceErrorCategory.unsupportedPlatform =>
        l10n.validationErrorUnsupportedPlatform,
      EvidenceErrorCategory.providerUpdateRequired =>
        l10n.validationErrorProviderUpdateRequired,
      EvidenceErrorCategory.providerUnavailable =>
        l10n.validationErrorProviderUnavailable,
      EvidenceErrorCategory.permissionDenied =>
        l10n.validationErrorPermissionDenied,
      EvidenceErrorCategory.permissionSettingsRequired =>
        l10n.validationErrorPermissionSettingsRequired,
      EvidenceErrorCategory.permissionRestricted =>
        l10n.validationErrorPermissionRestricted,
      EvidenceErrorCategory.protectedDataUnavailable =>
        l10n.validationErrorProtectedDataUnavailable,
      EvidenceErrorCategory.timeZoneUnavailable =>
        l10n.validationErrorTimeZoneUnavailable,
      EvidenceErrorCategory.healthReadFailed =>
        l10n.validationErrorHealthReadFailed,
      EvidenceErrorCategory.readingRequired =>
        l10n.validationErrorReadingRequired,
      EvidenceErrorCategory.networkUnavailable =>
        l10n.validationErrorNetworkUnavailable,
      EvidenceErrorCategory.reauthenticationRequired =>
        l10n.validationErrorReauthenticationRequired,
      EvidenceErrorCategory.cachedSnapshot =>
        l10n.validationErrorCachedSnapshot,
      EvidenceErrorCategory.invalidResponse =>
        l10n.validationErrorInvalidResponse,
      EvidenceErrorCategory.journalLimitReached =>
        l10n.validationErrorJournalLimit,
      EvidenceErrorCategory.unexpectedFailure => l10n.validationErrorUnexpected,
    };
  }
  if (error is FormatException) {
    return l10n.validationErrorInvalidEvidence;
  }
  return l10n.validationErrorGeneric;
}
