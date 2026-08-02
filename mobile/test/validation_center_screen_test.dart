import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/validation/application/validation_evidence_controller.dart';
import 'package:walking_rpg_mobile/features/validation/application/validation_evidence_exporter.dart';
import 'package:walking_rpg_mobile/features/validation/domain/device_validation_evidence.dart';
import 'package:walking_rpg_mobile/features/validation/presentation/validation_center_screen.dart';

import 'support/first_journey_fixture.dart';
import 'support/platform_fixture.dart';

void main() {
  testWidgets('runs explicit actions and exports verified launch evidence', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _RecordingValidationEvidenceExporter exporter =
        _RecordingValidationEvidenceExporter();
    int readCalls = 0;
    int monotonic = 0;
    final ValidationEvidenceController controller =
        ValidationEvidenceController(
          ownerId: 'owner-1',
          activeOwnerProvider: () => 'owner-1',
          sessionRevision: 0,
          activeSessionRevisionProvider: () => 0,
          launch: EvidenceLaunchMetadata(
            startedAtUtc: DateTime.utc(2026, 7, 31, 18),
            platform: 'android',
            operatingSystemVersion: 'Android 16',
            appVersion: '0.1.0',
            buildNumber: '46',
            sourceGitSha: '0123456789abcdef0123456789abcdef01234567',
            buildMode: 'debug',
            authenticationMode: 'oidc',
            healthSource: EvidenceHealthSource.healthConnect,
          ),
          stepReader: () async {
            readCalls += 1;
            return StepReading(
              authoritativeTotal: 3000,
              localDate: DateTime(2026, 7, 31),
              timeZone: 'Europe/Berlin',
            );
          },
          synchronizer: (_) async => firstJourneyActivityResult,
          homeLoader: () async => firstJourneyHome(synced: true, energy: 30),
          platformLoader: () async => platformSnapshot(
            completedOnboardingSteps: const <String>[
              'welcome',
              'health-permission',
              'first-sync',
            ],
            totalAcceptedSteps: 3000,
          ),
          clock: () => DateTime.utc(2026, 7, 31, 18, 4),
          monotonicMillis: () {
            monotonic += 5;
            return monotonic;
          },
        );
    addTearDown(controller.dispose);
    final SemanticsHandle semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: ValidationCenterScreen(
          controller: controller,
          activeOwnerProvider: () => 'owner-1',
          exporter: exporter,
        ),
      ),
    );

    expect(find.text('Validation Center'), findsOneWidget);
    expect(find.byType(ExpeditionBackdrop), findsOneWidget);
    expect(find.text('Проверка реального устройства'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Validation Center. Внутренний non-release контур. '
        'Записей журнала: 0 из 64.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('validation-source-sha')), findsOneWidget);
    expect(find.text('Журнал · 0/64'), findsOneWidget);

    await _tapAction(
      tester,
      const Key('validation-read-button'),
      isComplete: () =>
          !controller.busy && controller.snapshot.latestHealth != null,
    );
    expect(readCalls, 1);
    expect(find.text('Aggregated total: 3000'), findsOneWidget);
    expect(find.text('Журнал · 3/64'), findsOneWidget);

    await _tapAction(
      tester,
      const Key('validation-sync-button'),
      isComplete: () =>
          !controller.busy && controller.snapshot.latestSync != null,
    );
    expect(readCalls, 1);
    expect(find.text('ENERGY: +30 (balance 30)'), findsOneWidget);

    await _tapAction(
      tester,
      const Key('validation-checkpoint-button'),
      isComplete: () =>
          !controller.busy &&
          controller.snapshot.authoritativeCheckpoint != null,
    );
    expect(find.text('Accepted total: 3000'), findsWidgets);
    expect(find.text('Журнал · 5/64'), findsOneWidget);

    final Finder exportButton = find.byKey(
      const Key('validation-export-button'),
    );
    await tester.scrollUntilVisible(
      exportButton,
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(exportButton);
    await tester.pump();
    expect(exporter.sharedJson, isNotNull);
    expect(DeviceValidationEvidenceCodec.verify(exporter.sharedJson!), isTrue);
    expect(exporter.sharedJson, isNot(contains('owner-1')));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    exporter.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('validation-last-export')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('compact validation center stays scrollable with enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ValidationEvidenceController controller = _idleValidationController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: ValidationCenterScreen(
          controller: controller,
          activeOwnerProvider: () => 'owner-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapAction(
      tester,
      const Key('validation-read-button'),
      isComplete: () =>
          !controller.busy && controller.snapshot.latestHealth != null,
    );
    await _tapAction(
      tester,
      const Key('validation-sync-button'),
      isComplete: () =>
          !controller.busy && controller.snapshot.latestSync != null,
    );
    await _tapAction(
      tester,
      const Key('validation-checkpoint-button'),
      isComplete: () =>
          !controller.busy &&
          controller.snapshot.authoritativeCheckpoint != null,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('validation-export-button')),
      240,
      scrollable: find.byType(Scrollable),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ExpeditionBackdrop), findsOneWidget);
    expect(find.byKey(const Key('validation-safety-note')), findsOneWidget);
    expect(find.byKey(const Key('validation-export-button')), findsOneWidget);
    expect(find.text('Журнал · 5/64'), findsOneWidget);
  });
}

ValidationEvidenceController _idleValidationController() {
  return ValidationEvidenceController(
    ownerId: 'owner-1',
    activeOwnerProvider: () => 'owner-1',
    sessionRevision: 0,
    activeSessionRevisionProvider: () => 0,
    launch: EvidenceLaunchMetadata(
      startedAtUtc: DateTime.utc(2026, 8, 2, 8),
      platform: 'android',
      operatingSystemVersion: 'Android 16',
      appVersion: '0.1.0',
      buildNumber: '47',
      sourceGitSha: '0123456789abcdef0123456789abcdef01234567',
      buildMode: 'debug',
      authenticationMode: 'oidc',
      healthSource: EvidenceHealthSource.healthConnect,
    ),
    stepReader: () async => StepReading(
      authoritativeTotal: 3000,
      localDate: DateTime(2026, 8, 2),
      timeZone: 'Europe/Berlin',
    ),
    synchronizer: (_) async => firstJourneyActivityResult,
    homeLoader: () async => firstJourneyHome(synced: true, energy: 30),
    platformLoader: () async => platformSnapshot(
      completedOnboardingSteps: const <String>[
        'welcome',
        'health-permission',
        'first-sync',
      ],
      totalAcceptedSteps: 3000,
    ),
    clock: () => DateTime.utc(2026, 8, 2, 8, 4),
    monotonicMillis: () => 5,
  );
}

Future<void> _tapAction(
  WidgetTester tester,
  Key key, {
  required bool Function() isComplete,
}) async {
  final Finder target = find.byKey(key);
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: find.byType(Scrollable),
  );
  await tester.tap(target);
  for (int attempt = 0; attempt < 20 && !isComplete(); attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(isComplete(), isTrue, reason: 'Validation action did not complete');
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 300));
}

final class _RecordingValidationEvidenceExporter
    implements ValidationEvidenceExportService {
  final Completer<ValidationEvidenceExportArtifact> _completion =
      Completer<ValidationEvidenceExportArtifact>();
  String? sharedJson;

  @override
  Future<ValidationEvidenceExportArtifact> saveAndShare(
    String json, {
    Rect? sharePositionOrigin,
    ValidationEvidencePreShareCheck? beforeShare,
  }) {
    if (!DeviceValidationEvidenceCodec.verify(json)) {
      throw const FormatException('Evidence must be verified before sharing');
    }
    beforeShare?.call();
    sharedJson = json;
    return _completion.future;
  }

  void complete() {
    _completion.complete(
      ValidationEvidenceExportArtifact(
        fileName: 'walking-rpg-validation-20260731T180500000Z.json',
        path: 'memory://walking-rpg-validation.json',
        createdAt: DateTime.utc(2026, 7, 31, 18, 5),
      ),
    );
  }
}
