import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/activity/data/platform_health_step_source.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/onboarding/domain/first_journey_progress.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/validation/domain/device_validation_evidence.dart';

typedef ValidationStepReader = Future<StepReading> Function();
typedef ValidationReadingSynchronizer =
    Future<ActivitySyncResult> Function(StepReading reading);
typedef ValidationHomeLoader = Future<HomeSnapshot> Function();
typedef ValidationPlatformLoader = Future<PlatformSnapshot> Function();
typedef ValidationClock = DateTime Function();
typedef ValidationMonotonicMillis = int Function();
typedef ValidationOwnerProvider = String? Function();
typedef ValidationSessionRevisionProvider = int Function();

final class ValidationEvidenceController extends ChangeNotifier {
  ValidationEvidenceController({
    required String ownerId,
    required ValidationOwnerProvider activeOwnerProvider,
    required int sessionRevision,
    required ValidationSessionRevisionProvider activeSessionRevisionProvider,
    required EvidenceLaunchMetadata launch,
    required ValidationHomeLoader homeLoader,
    required ValidationPlatformLoader platformLoader,
    ValidationStepReader? stepReader,
    ValidationReadingSynchronizer? synchronizer,
    ValidationClock? clock,
    ValidationMonotonicMillis? monotonicMillis,
    this.includeManualEntries = false,
  }) : _ownerId = _requireOwner(ownerId),
       _activeOwnerProvider = activeOwnerProvider,
       _sessionRevision = sessionRevision,
       _activeSessionRevisionProvider = activeSessionRevisionProvider,
       _stepReader = stepReader,
       _synchronizer = synchronizer,
       _homeLoader = homeLoader,
       _platformLoader = platformLoader,
       _clock = clock ?? DateTime.now,
       _monotonicMillis = monotonicMillis ?? _createMonotonicMillis(),
       _snapshot = DeviceValidationEvidenceSnapshot(
         launch: launch,
         updatedAtUtc: launch.startedAtUtc,
         journal: const <EvidenceJournalEntry>[],
       );

  final String _ownerId;
  final ValidationOwnerProvider _activeOwnerProvider;
  final int _sessionRevision;
  final ValidationSessionRevisionProvider _activeSessionRevisionProvider;
  final ValidationStepReader? _stepReader;
  final ValidationReadingSynchronizer? _synchronizer;
  final ValidationHomeLoader _homeLoader;
  final ValidationPlatformLoader _platformLoader;
  final ValidationClock _clock;
  final ValidationMonotonicMillis _monotonicMillis;
  final bool includeManualEntries;

  DeviceValidationEvidenceSnapshot _snapshot;
  StepReading? _latestReading;
  bool _busy = false;
  bool _disposed = false;
  bool _journalLimitReached = false;

  DeviceValidationEvidenceSnapshot get snapshot => _snapshot;

  bool get busy => _busy;

  bool get canSynchronize => _latestReading != null && _synchronizer != null;

  bool get journalFull =>
      _journalLimitReached ||
      _snapshot.journal.length >=
          DeviceValidationEvidenceCodec.maxJournalEntries;

  Future<void> readHealth({required String activeOwnerId}) async {
    _begin(activeOwnerId, requiredEntries: 3, scenario: EvidenceScenario.read);
    final DateTime startedAt = _evidenceNowUtc();
    final int startedTick = _monotonicMillis();
    final ValidationStepReader? reader = _stepReader;
    if (reader == null) {
      const _HealthFailure failure = _HealthFailure(
        phase: EvidenceScenario.provider,
        status: EvidenceObservationStatus.blocked,
        outcome: EvidenceOutcome.blocked,
        providerState: EvidenceProviderState.unavailable,
        permissionState: EvidencePermissionState.unknown,
        category: EvidenceErrorCategory.unsupportedPlatform,
      );
      _recordHealthFailure(failure, startedAt, _elapsed(startedTick));
      _finish();
      throw ValidationActionException(failure.category);
    }

    try {
      final StepReading reading = await reader();
      _ensureOwner(activeOwnerId);
      final int durationMs = _elapsed(startedTick);
      _latestReading = reading;
      final bool development =
          _snapshot.launch.healthSource == EvidenceHealthSource.development;
      final EvidenceHealthObservation observation = EvidenceHealthObservation(
        status: EvidenceObservationStatus.succeeded,
        providerState: development
            ? EvidenceProviderState.notApplicable
            : EvidenceProviderState.available,
        permissionState: development
            ? EvidencePermissionState.notRequired
            : EvidencePermissionState.requestSucceeded,
        authoritativeTotal: reading.authoritativeTotal,
        localDate: reading.localDateIso,
        timeZone: reading.timeZone,
        includeManualEntries: includeManualEntries,
        durationMs: durationMs,
      );
      _append(<_JournalDraft>[
        _JournalDraft.passed(EvidenceScenario.provider, startedAt),
        _JournalDraft.passed(EvidenceScenario.permission, startedAt),
        _JournalDraft.passed(
          EvidenceScenario.read,
          startedAt,
          durationMs: durationMs,
        ),
      ], latestHealth: observation);
    } on Object catch (error) {
      _ensureOwner(activeOwnerId);
      _latestReading = null;
      final _HealthFailure failure = _healthFailure(error);
      _recordHealthFailure(failure, startedAt, _elapsed(startedTick));
      throw ValidationActionException(failure.category);
    } finally {
      _finish();
    }
  }

  Future<void> synchronize({required String activeOwnerId}) async {
    _begin(activeOwnerId, requiredEntries: 1, scenario: EvidenceScenario.sync);
    final DateTime startedAt = _evidenceNowUtc();
    final int startedTick = _monotonicMillis();
    final StepReading? reading = _latestReading;
    final ValidationReadingSynchronizer? synchronizer = _synchronizer;
    if (reading == null || synchronizer == null) {
      const EvidenceErrorCategory category =
          EvidenceErrorCategory.readingRequired;
      final int durationMs = _elapsed(startedTick);
      _append(
        <_JournalDraft>[
          _JournalDraft.unsuccessful(
            EvidenceScenario.sync,
            EvidenceOutcome.blocked,
            startedAt,
            category,
            durationMs: durationMs,
          ),
        ],
        latestSync: EvidenceSyncObservation.unsuccessful(
          status: EvidenceObservationStatus.blocked,
          durationMs: durationMs,
          errorCategory: category,
        ),
      );
      _finish();
      throw const ValidationActionException(category);
    }

    try {
      final ActivitySyncResult result = await synchronizer(reading);
      _ensureOwner(activeOwnerId);
      final int durationMs = _elapsed(startedTick);
      _append(
        <_JournalDraft>[
          _JournalDraft.passed(
            EvidenceScenario.sync,
            startedAt,
            durationMs: durationMs,
          ),
        ],
        latestSync: EvidenceSyncObservation.succeeded(
          acceptedTotal: result.acceptedTotal,
          acceptedDelta: result.acceptedDelta,
          energyGranted: result.energyGranted,
          energyBalanceAfter: result.energyBalanceAfter,
          economyVersion: result.economyVersion,
          stateVersion: result.stateVersion,
          riskStatus: result.riskStatus,
          serverTime: result.serverTime,
          durationMs: durationMs,
        ),
      );
    } on Object catch (error) {
      _ensureOwner(activeOwnerId);
      final EvidenceErrorCategory category = _generalFailure(error);
      final int durationMs = _elapsed(startedTick);
      _append(
        <_JournalDraft>[
          _JournalDraft.unsuccessful(
            EvidenceScenario.sync,
            EvidenceOutcome.failed,
            startedAt,
            category,
            durationMs: durationMs,
          ),
        ],
        latestSync: EvidenceSyncObservation.unsuccessful(
          status: EvidenceObservationStatus.failed,
          durationMs: durationMs,
          errorCategory: category,
        ),
      );
      throw ValidationActionException(category);
    } finally {
      _finish();
    }
  }

  Future<void> captureAuthoritativeCheckpoint({
    required String activeOwnerId,
  }) async {
    _begin(
      activeOwnerId,
      requiredEntries: 1,
      scenario: EvidenceScenario.checkpoint,
    );
    final DateTime startedAt = _evidenceNowUtc();
    final int startedTick = _monotonicMillis();
    try {
      final List<Object> values = await Future.wait<Object>(<Future<Object>>[
        _homeLoader(),
        _platformLoader(),
      ]);
      final HomeSnapshot home = values[0] as HomeSnapshot;
      final PlatformSnapshot platform = values[1] as PlatformSnapshot;
      _ensureOwner(activeOwnerId);
      if (home.isCached || platform.isCached) {
        throw const _CachedSnapshotEvidenceException();
      }
      if (home.contentVersion != platform.contentVersion) {
        throw const FormatException(
          'Authoritative content versions не совпадают',
        );
      }
      final FirstJourneyProgress progress = FirstJourneyProgress(
        home: home,
        platform: platform,
      );
      final int durationMs = _elapsed(startedTick);
      final AuthoritativeJourneyFacts facts = AuthoritativeJourneyFacts(
        homeActivityStateVersion: home.activityStateVersion,
        homeEconomyVersion: home.economyVersion,
        platformStateVersion: platform.stateVersion,
        contentVersion: home.contentVersion,
        dailySteps: home.dailySteps,
        dailyGoal: home.dailyGoal,
        availableEnergy: home.availableEnergy,
        currentNodeId: home.currentNodeId,
        expeditionStatus: home.expeditionStatus,
        expeditionProgress: home.expeditionProgress,
        hasPendingEventResult: home.pendingEventResult != null,
        lastActivitySyncPresent: home.lastActivitySyncAt != null,
        totalAcceptedSteps: platform.userState.totalAcceptedSteps,
        hasSuccessfulActivitySync: platform.userState.hasSuccessfulActivitySync,
        resolvedEventCount: platform.userState.resolvedEventCount,
        completedMilestones: FirstJourneyProgress.steps
            .where(progress.completedSteps.contains)
            .toList(growable: false),
        firstJourneyStage: progress.stage.name,
        firstJourneyComplete: progress.complete,
        homeServerTime: home.serverTime,
        platformServerTime: platform.serverTime,
        durationMs: durationMs,
      );
      _append(<_JournalDraft>[
        _JournalDraft.passed(
          EvidenceScenario.checkpoint,
          startedAt,
          durationMs: durationMs,
        ),
      ], authoritativeCheckpoint: facts);
    } on Object catch (error) {
      _ensureOwner(activeOwnerId);
      final EvidenceErrorCategory category = _generalFailure(error);
      final int durationMs = _elapsed(startedTick);
      _append(<_JournalDraft>[
        _JournalDraft.unsuccessful(
          EvidenceScenario.checkpoint,
          error is _CachedSnapshotEvidenceException
              ? EvidenceOutcome.blocked
              : EvidenceOutcome.failed,
          startedAt,
          category,
          durationMs: durationMs,
        ),
      ], clearAuthoritativeCheckpoint: true);
      throw ValidationActionException(category);
    } finally {
      _finish();
    }
  }

  String encode({required String activeOwnerId}) {
    _ensureOwner(activeOwnerId);
    return DeviceValidationEvidenceCodec.encode(
      _snapshot,
      exportedAtUtc: _evidenceNowUtc(),
    );
  }

  void ensureActiveOwner({required String activeOwnerId}) {
    _ensureOwner(activeOwnerId);
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _snapshot = DeviceValidationEvidenceSnapshot(
      launch: _snapshot.launch,
      updatedAtUtc: _evidenceNowUtc(),
      journal: const <EvidenceJournalEntry>[],
    );
    _busy = false;
    _disposed = true;
    _journalLimitReached = false;
    _latestReading = null;
    super.dispose();
  }

  void _recordHealthFailure(
    _HealthFailure failure,
    DateTime startedAt,
    int durationMs,
  ) {
    final List<_JournalDraft> drafts = <_JournalDraft>[];
    if (failure.phase != EvidenceScenario.provider &&
        failure.providerState == EvidenceProviderState.available) {
      drafts.add(_JournalDraft.passed(EvidenceScenario.provider, startedAt));
    }
    if (failure.phase == EvidenceScenario.read &&
        failure.permissionState == EvidencePermissionState.requestSucceeded) {
      drafts.add(_JournalDraft.passed(EvidenceScenario.permission, startedAt));
    }
    drafts.add(
      _JournalDraft.unsuccessful(
        failure.phase,
        failure.outcome,
        startedAt,
        failure.category,
        durationMs: durationMs,
      ),
    );
    _append(
      drafts,
      latestHealth: EvidenceHealthObservation(
        status: failure.status,
        providerState: failure.providerState,
        permissionState: failure.permissionState,
        includeManualEntries: includeManualEntries,
        durationMs: durationMs,
        errorCategory: failure.category,
      ),
    );
  }

  void _begin(
    String activeOwnerId, {
    required int requiredEntries,
    required EvidenceScenario scenario,
  }) {
    _ensureOwner(activeOwnerId);
    if (_busy) {
      throw const ValidationActionException(
        EvidenceErrorCategory.unexpectedFailure,
      );
    }
    if (_journalLimitReached) {
      throw const ValidationActionException(
        EvidenceErrorCategory.journalLimitReached,
      );
    }
    const int lastCompleteEntry =
        DeviceValidationEvidenceCodec.maxJournalEntries - 1;
    if (_snapshot.journal.length + requiredEntries > lastCompleteEntry) {
      _journalLimitReached = true;
      if (_snapshot.journal.length <
          DeviceValidationEvidenceCodec.maxJournalEntries) {
        _append(<_JournalDraft>[
          _JournalDraft.unsuccessful(
            scenario,
            EvidenceOutcome.blocked,
            _evidenceNowUtc(),
            EvidenceErrorCategory.journalLimitReached,
          ),
        ]);
      }
      throw const ValidationActionException(
        EvidenceErrorCategory.journalLimitReached,
      );
    }
    _busy = true;
    _notify();
  }

  void _finish() {
    _busy = false;
    _notify();
  }

  void _ensureOwner(String activeOwnerId) {
    if (_disposed) {
      throw const ValidationOwnerMismatchException();
    }
    final String? liveOwner;
    final int liveSessionRevision;
    try {
      liveOwner = _activeOwnerProvider();
      liveSessionRevision = _activeSessionRevisionProvider();
    } on Object {
      throw const ValidationOwnerMismatchException();
    }
    if (activeOwnerId != _ownerId ||
        liveOwner != _ownerId ||
        liveSessionRevision != _sessionRevision) {
      throw const ValidationOwnerMismatchException();
    }
  }

  void _append(
    List<_JournalDraft> drafts, {
    EvidenceHealthObservation? latestHealth,
    EvidenceSyncObservation? latestSync,
    AuthoritativeJourneyFacts? authoritativeCheckpoint,
    bool clearAuthoritativeCheckpoint = false,
  }) {
    final List<EvidenceJournalEntry> journal = <EvidenceJournalEntry>[
      ..._snapshot.journal,
    ];
    DateTime updatedAtUtc = _evidenceNowUtc();
    for (final _JournalDraft draft in drafts) {
      if (draft.startedAtUtc.isAfter(updatedAtUtc)) {
        updatedAtUtc = draft.startedAtUtc;
      }
      journal.add(
        EvidenceJournalEntry(
          sequence: journal.length + 1,
          scenario: draft.scenario,
          outcome: draft.outcome,
          startedAtUtc: draft.startedAtUtc,
          durationMs: draft.durationMs,
          errorCategory: draft.errorCategory,
        ),
      );
    }
    _snapshot = DeviceValidationEvidenceSnapshot(
      launch: _snapshot.launch,
      updatedAtUtc: updatedAtUtc,
      latestHealth: latestHealth ?? _snapshot.latestHealth,
      latestSync: latestSync ?? _snapshot.latestSync,
      authoritativeCheckpoint: clearAuthoritativeCheckpoint
          ? null
          : authoritativeCheckpoint ?? _snapshot.authoritativeCheckpoint,
      journal: journal,
    );
    _notify();
  }

  int _elapsed(int startedTick) {
    return (_monotonicMillis() - startedTick)
        .clamp(0, const Duration(days: 1).inMilliseconds)
        .toInt();
  }

  DateTime _evidenceNowUtc() {
    final DateTime current = _clock().toUtc();
    return current.isBefore(_snapshot.updatedAtUtc)
        ? _snapshot.updatedAtUtc
        : current;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

ValidationMonotonicMillis _createMonotonicMillis() {
  final Stopwatch stopwatch = Stopwatch()..start();
  return () => stopwatch.elapsedMilliseconds;
}

EvidenceLaunchMetadata createValidationLaunchMetadata({
  required String authenticationMode,
  required String appVersion,
  required String buildNumber,
  required String operatingSystemVersion,
  ValidationClock? clock,
}) {
  final EvidenceHealthSource source = AppEnvironment.enableDemoActivitySync
      ? EvidenceHealthSource.development
      : Platform.isIOS
      ? EvidenceHealthSource.healthKit
      : Platform.isAndroid
      ? EvidenceHealthSource.healthConnect
      : EvidenceHealthSource.unsupported;
  const String buildMode = kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';
  return EvidenceLaunchMetadata(
    startedAtUtc: (clock ?? DateTime.now)().toUtc(),
    platform: Platform.operatingSystem,
    operatingSystemVersion: operatingSystemVersion,
    appVersion: appVersion,
    buildNumber: buildNumber,
    sourceGitSha: AppEnvironment.validationSourceGitSha,
    buildMode: buildMode,
    authenticationMode: authenticationMode,
    healthSource: source,
  );
}

final class ValidationActionException implements Exception {
  const ValidationActionException(this.category);

  final EvidenceErrorCategory category;

  @override
  String toString() => category.wireName;
}

final class ValidationOwnerMismatchException implements Exception {
  const ValidationOwnerMismatchException();

  @override
  String toString() => 'Validation evidence owner is no longer active';
}

final class _CachedSnapshotEvidenceException implements Exception {
  const _CachedSnapshotEvidenceException();
}

final class _JournalDraft {
  const _JournalDraft({
    required this.scenario,
    required this.outcome,
    required this.startedAtUtc,
    required this.durationMs,
    this.errorCategory,
  });

  factory _JournalDraft.passed(
    EvidenceScenario scenario,
    DateTime startedAtUtc, {
    int durationMs = 0,
  }) {
    return _JournalDraft(
      scenario: scenario,
      outcome: EvidenceOutcome.passed,
      startedAtUtc: startedAtUtc,
      durationMs: durationMs,
    );
  }

  factory _JournalDraft.unsuccessful(
    EvidenceScenario scenario,
    EvidenceOutcome outcome,
    DateTime startedAtUtc,
    EvidenceErrorCategory errorCategory, {
    int durationMs = 0,
  }) {
    return _JournalDraft(
      scenario: scenario,
      outcome: outcome,
      startedAtUtc: startedAtUtc,
      durationMs: durationMs,
      errorCategory: errorCategory,
    );
  }

  final EvidenceScenario scenario;
  final EvidenceOutcome outcome;
  final DateTime startedAtUtc;
  final int durationMs;
  final EvidenceErrorCategory? errorCategory;
}

final class _HealthFailure {
  const _HealthFailure({
    required this.phase,
    required this.status,
    required this.outcome,
    required this.providerState,
    required this.permissionState,
    required this.category,
  });

  final EvidenceScenario phase;
  final EvidenceObservationStatus status;
  final EvidenceOutcome outcome;
  final EvidenceProviderState providerState;
  final EvidencePermissionState permissionState;
  final EvidenceErrorCategory category;
}

_HealthFailure _healthFailure(Object error) {
  if (error is! PlatformHealthStepException) {
    return const _HealthFailure(
      phase: EvidenceScenario.read,
      status: EvidenceObservationStatus.failed,
      outcome: EvidenceOutcome.failed,
      providerState: EvidenceProviderState.unknown,
      permissionState: EvidencePermissionState.unknown,
      category: EvidenceErrorCategory.unexpectedFailure,
    );
  }
  return switch (error.failure) {
    PlatformHealthStepFailure.unsupportedPlatform => const _HealthFailure(
      phase: EvidenceScenario.provider,
      status: EvidenceObservationStatus.blocked,
      outcome: EvidenceOutcome.blocked,
      providerState: EvidenceProviderState.unavailable,
      permissionState: EvidencePermissionState.unknown,
      category: EvidenceErrorCategory.unsupportedPlatform,
    ),
    PlatformHealthStepFailure.providerUpdateRequired => const _HealthFailure(
      phase: EvidenceScenario.provider,
      status: EvidenceObservationStatus.blocked,
      outcome: EvidenceOutcome.blocked,
      providerState: EvidenceProviderState.updateRequired,
      permissionState: EvidencePermissionState.unknown,
      category: EvidenceErrorCategory.providerUpdateRequired,
    ),
    PlatformHealthStepFailure.providerUnavailable => const _HealthFailure(
      phase: EvidenceScenario.provider,
      status: EvidenceObservationStatus.blocked,
      outcome: EvidenceOutcome.blocked,
      providerState: EvidenceProviderState.unavailable,
      permissionState: EvidencePermissionState.unknown,
      category: EvidenceErrorCategory.providerUnavailable,
    ),
    PlatformHealthStepFailure.activityRecognitionDenied ||
    PlatformHealthStepFailure.authorizationDenied => const _HealthFailure(
      phase: EvidenceScenario.permission,
      status: EvidenceObservationStatus.failed,
      outcome: EvidenceOutcome.failed,
      providerState: EvidenceProviderState.available,
      permissionState: EvidencePermissionState.denied,
      category: EvidenceErrorCategory.permissionDenied,
    ),
    PlatformHealthStepFailure.activityRecognitionSettingsRequired =>
      const _HealthFailure(
        phase: EvidenceScenario.permission,
        status: EvidenceObservationStatus.blocked,
        outcome: EvidenceOutcome.blocked,
        providerState: EvidenceProviderState.available,
        permissionState: EvidencePermissionState.settingsRequired,
        category: EvidenceErrorCategory.permissionSettingsRequired,
      ),
    PlatformHealthStepFailure.activityRecognitionRestricted =>
      const _HealthFailure(
        phase: EvidenceScenario.permission,
        status: EvidenceObservationStatus.blocked,
        outcome: EvidenceOutcome.blocked,
        providerState: EvidenceProviderState.available,
        permissionState: EvidencePermissionState.restricted,
        category: EvidenceErrorCategory.permissionRestricted,
      ),
    PlatformHealthStepFailure.protectedDataUnavailable => const _HealthFailure(
      phase: EvidenceScenario.read,
      status: EvidenceObservationStatus.failed,
      outcome: EvidenceOutcome.failed,
      providerState: EvidenceProviderState.available,
      permissionState: EvidencePermissionState.requestSucceeded,
      category: EvidenceErrorCategory.protectedDataUnavailable,
    ),
    PlatformHealthStepFailure.timeZoneUnavailable => const _HealthFailure(
      phase: EvidenceScenario.read,
      status: EvidenceObservationStatus.failed,
      outcome: EvidenceOutcome.failed,
      providerState: EvidenceProviderState.available,
      permissionState: EvidencePermissionState.requestSucceeded,
      category: EvidenceErrorCategory.timeZoneUnavailable,
    ),
    PlatformHealthStepFailure.readFailed => const _HealthFailure(
      phase: EvidenceScenario.read,
      status: EvidenceObservationStatus.failed,
      outcome: EvidenceOutcome.failed,
      providerState: EvidenceProviderState.available,
      permissionState: EvidencePermissionState.requestSucceeded,
      category: EvidenceErrorCategory.healthReadFailed,
    ),
  };
}

EvidenceErrorCategory _generalFailure(Object error) {
  if (error is _CachedSnapshotEvidenceException) {
    return EvidenceErrorCategory.cachedSnapshot;
  }
  if (error is AuthReauthenticationRequiredException ||
      error is AuthAccountDeletedException) {
    return EvidenceErrorCategory.reauthenticationRequired;
  }
  if (error is HomeNetworkException ||
      error is SocketException ||
      error is TimeoutException) {
    return EvidenceErrorCategory.networkUnavailable;
  }
  if (error is FormatException || error is ArgumentError) {
    return EvidenceErrorCategory.invalidResponse;
  }
  return EvidenceErrorCategory.unexpectedFailure;
}

String _requireOwner(String value) {
  if (value.isEmpty) {
    throw const ValidationOwnerMismatchException();
  }
  return value;
}
