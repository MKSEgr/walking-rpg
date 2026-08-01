import 'dart:convert';

import 'package:crypto/crypto.dart';

enum EvidenceHealthSource {
  healthKit('healthkit'),
  healthConnect('health_connect'),
  development('development'),
  unsupported('unsupported');

  const EvidenceHealthSource(this.wireName);

  final String wireName;
}

enum EvidenceObservationStatus {
  succeeded('succeeded'),
  failed('failed'),
  blocked('blocked');

  const EvidenceObservationStatus(this.wireName);

  final String wireName;
}

enum EvidenceProviderState {
  available('available'),
  updateRequired('update_required'),
  unavailable('unavailable'),
  notApplicable('not_applicable'),
  unknown('unknown');

  const EvidenceProviderState(this.wireName);

  final String wireName;
}

enum EvidencePermissionState {
  requestSucceeded('request_succeeded'),
  denied('denied'),
  settingsRequired('settings_required'),
  restricted('restricted'),
  notRequired('not_required'),
  unknown('unknown');

  const EvidencePermissionState(this.wireName);

  final String wireName;
}

enum EvidenceScenario {
  provider('provider'),
  permission('permission'),
  read('read'),
  sync('sync'),
  checkpoint('checkpoint');

  const EvidenceScenario(this.wireName);

  final String wireName;
}

enum EvidenceOutcome {
  passed('passed'),
  failed('failed'),
  blocked('blocked');

  const EvidenceOutcome(this.wireName);

  final String wireName;
}

enum EvidenceErrorCategory {
  unsupportedPlatform('unsupported_platform'),
  providerUpdateRequired('provider_update_required'),
  providerUnavailable('provider_unavailable'),
  permissionDenied('permission_denied'),
  permissionSettingsRequired('permission_settings_required'),
  permissionRestricted('permission_restricted'),
  protectedDataUnavailable('protected_data_unavailable'),
  timeZoneUnavailable('timezone_unavailable'),
  healthReadFailed('health_read_failed'),
  readingRequired('reading_required'),
  networkUnavailable('network_unavailable'),
  reauthenticationRequired('reauthentication_required'),
  cachedSnapshot('cached_snapshot'),
  invalidResponse('invalid_response'),
  journalLimitReached('journal_limit_reached'),
  unexpectedFailure('unexpected_failure');

  const EvidenceErrorCategory(this.wireName);

  final String wireName;
}

final class EvidenceLaunchMetadata {
  EvidenceLaunchMetadata({
    required DateTime startedAtUtc,
    required String platform,
    required String operatingSystemVersion,
    required String appVersion,
    required String buildNumber,
    required String sourceGitSha,
    required String buildMode,
    required String authenticationMode,
    required this.healthSource,
  }) : startedAtUtc = startedAtUtc.toUtc(),
       platform = _oneOf(platform, 'platform', const <String>{
         'android',
         'ios',
       }),
       operatingSystemVersion = _safeText(
         operatingSystemVersion,
         'operatingSystemVersion',
       ),
       appVersion = _safeText(appVersion, 'appVersion'),
       buildNumber = _safeText(buildNumber, 'buildNumber'),
       sourceGitSha = _sourceSha(sourceGitSha),
       buildMode = _oneOf(buildMode, 'buildMode', const <String>{
         'debug',
         'profile',
       }),
       authenticationMode = _oneOf(
         authenticationMode,
         'authenticationMode',
         const <String>{'oidc', 'development'},
       ) {
    final bool compatibleSource =
        healthSource == EvidenceHealthSource.development ||
        (platform == 'android' &&
            healthSource == EvidenceHealthSource.healthConnect) ||
        (platform == 'ios' && healthSource == EvidenceHealthSource.healthKit);
    if (!compatibleSource) {
      throw const FormatException(
        'Health source не соответствует runtime platform',
      );
    }
  }

  final DateTime startedAtUtc;
  final String platform;
  final String operatingSystemVersion;
  final String appVersion;
  final String buildNumber;
  final String sourceGitSha;
  final String buildMode;
  final String authenticationMode;
  final EvidenceHealthSource healthSource;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'startedAtUtc': startedAtUtc.toIso8601String(),
      'platform': platform,
      'operatingSystemVersion': operatingSystemVersion,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'sourceGitSha': sourceGitSha,
      'buildMode': buildMode,
      'authenticationMode': authenticationMode,
      'healthSource': healthSource.wireName,
    };
  }
}

final class EvidenceHealthObservation {
  EvidenceHealthObservation({
    required this.status,
    required this.providerState,
    required this.permissionState,
    required this.includeManualEntries,
    required this.durationMs,
    this.authoritativeTotal,
    String? localDate,
    String? timeZone,
    this.errorCategory,
  }) : localDate = _optionalLocalDate(localDate),
       timeZone = _optionalTimeZone(timeZone) {
    _duration(durationMs);
    if (authoritativeTotal != null && authoritativeTotal! < 0) {
      throw ArgumentError.value(
        authoritativeTotal,
        'authoritativeTotal',
        'Значение не может быть отрицательным',
      );
    }
    if (status == EvidenceObservationStatus.succeeded &&
        (authoritativeTotal == null ||
            this.localDate == null ||
            this.timeZone == null ||
            errorCategory != null)) {
      throw const FormatException(
        'Успешное Health observation должно содержать total/date/timezone',
      );
    }
    if (status == EvidenceObservationStatus.succeeded) {
      final bool platformBacked =
          providerState == EvidenceProviderState.available &&
          permissionState == EvidencePermissionState.requestSucceeded;
      final bool development =
          providerState == EvidenceProviderState.notApplicable &&
          permissionState == EvidencePermissionState.notRequired;
      if (!platformBacked && !development) {
        throw const FormatException(
          'Успешное Health observation несовместимо с provider/permission',
        );
      }
    }
    if (status != EvidenceObservationStatus.succeeded &&
        errorCategory == null) {
      throw const FormatException(
        'Неуспешное Health observation требует error category',
      );
    }
    if (status != EvidenceObservationStatus.succeeded &&
        (authoritativeTotal != null ||
            this.localDate != null ||
            this.timeZone != null)) {
      throw const FormatException(
        'Неуспешное Health observation не содержит result facts',
      );
    }
    if (status != EvidenceObservationStatus.succeeded &&
        !_isValidHealthFailure(
          status: status,
          providerState: providerState,
          permissionState: permissionState,
          errorCategory: errorCategory!,
        )) {
      throw const FormatException(
        'Health failure несовместим с status/provider/permission/category',
      );
    }
  }

  final EvidenceObservationStatus status;
  final EvidenceProviderState providerState;
  final EvidencePermissionState permissionState;
  final int? authoritativeTotal;
  final String? localDate;
  final String? timeZone;
  final bool includeManualEntries;
  final int durationMs;
  final EvidenceErrorCategory? errorCategory;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'status': status.wireName,
      'providerState': providerState.wireName,
      'permissionState': permissionState.wireName,
      'authoritativeTotal': authoritativeTotal,
      'localDate': localDate,
      'timeZone': timeZone,
      'includeManualEntries': includeManualEntries,
      'durationMs': durationMs,
      'errorCategory': errorCategory?.wireName,
    };
  }
}

final class EvidenceSyncObservation {
  EvidenceSyncObservation.succeeded({
    required int acceptedTotal,
    required int acceptedDelta,
    required int energyGranted,
    required int energyBalanceAfter,
    required int economyVersion,
    required int stateVersion,
    required String riskStatus,
    required String serverTime,
    required this.durationMs,
  }) : status = EvidenceObservationStatus.succeeded,
       acceptedTotal = acceptedTotal,
       acceptedDelta = acceptedDelta,
       energyGranted = energyGranted,
       energyBalanceAfter = energyBalanceAfter,
       economyVersion = economyVersion,
       stateVersion = stateVersion,
       riskStatus = _oneOf(riskStatus, 'riskStatus', const <String>{
         'ACCEPTED',
         'NO_NEW_ACTIVITY',
         'TOTAL_DECREASED',
       }),
       serverTime = _timestampText(serverTime, 'serverTime'),
       errorCategory = null {
    _nonNegative(<String, int>{
      'acceptedTotal': acceptedTotal,
      'acceptedDelta': acceptedDelta,
      'energyGranted': energyGranted,
      'energyBalanceAfter': energyBalanceAfter,
      'economyVersion': economyVersion,
      'stateVersion': stateVersion,
    });
    if (acceptedDelta > acceptedTotal) {
      throw const FormatException(
        'Sync delta/energy не соответствуют accepted total',
      );
    }
    final int previousAcceptedTotal = acceptedTotal - acceptedDelta;
    final int expectedEnergy =
        acceptedTotal ~/ 100 - previousAcceptedTotal ~/ 100;
    if (energyGranted != expectedEnergy) {
      throw const FormatException(
        'Sync energy не соответствует пересечённым шаговым порогам',
      );
    }
    final bool accepted = this.riskStatus == 'ACCEPTED';
    if (accepted != (acceptedDelta > 0) ||
        (!accepted && acceptedDelta != 0) ||
        (acceptedDelta == 0 && energyGranted != 0)) {
      throw const FormatException(
        'Sync risk status не соответствует delta/energy',
      );
    }
    _duration(durationMs);
  }

  EvidenceSyncObservation.unsuccessful({
    required this.status,
    required this.durationMs,
    required EvidenceErrorCategory errorCategory,
  }) : acceptedTotal = null,
       acceptedDelta = null,
       energyGranted = null,
       energyBalanceAfter = null,
       economyVersion = null,
       stateVersion = null,
       riskStatus = null,
       serverTime = null,
       errorCategory = errorCategory {
    if (status == EvidenceObservationStatus.succeeded) {
      throw const FormatException(
        'Неуспешный sync требует failed/blocked и error category',
      );
    }
    if (!_isValidSyncFailure(status, errorCategory)) {
      throw const FormatException(
        'Sync failure несовместим с status/error category',
      );
    }
    _duration(durationMs);
  }

  final EvidenceObservationStatus status;
  final int? acceptedTotal;
  final int? acceptedDelta;
  final int? energyGranted;
  final int? energyBalanceAfter;
  final int? economyVersion;
  final int? stateVersion;
  final String? riskStatus;
  final String? serverTime;
  final int durationMs;
  final EvidenceErrorCategory? errorCategory;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'status': status.wireName,
      'acceptedTotal': acceptedTotal,
      'acceptedDelta': acceptedDelta,
      'energyGranted': energyGranted,
      'energyBalanceAfter': energyBalanceAfter,
      'economyVersion': economyVersion,
      'stateVersion': stateVersion,
      'riskStatus': riskStatus,
      'serverTime': serverTime,
      'durationMs': durationMs,
      'errorCategory': errorCategory?.wireName,
    };
  }
}

final class AuthoritativeJourneyFacts {
  AuthoritativeJourneyFacts({
    required this.homeActivityStateVersion,
    required this.homeEconomyVersion,
    required this.platformStateVersion,
    required String contentVersion,
    required this.dailySteps,
    required this.dailyGoal,
    required this.availableEnergy,
    required String currentNodeId,
    required String expeditionStatus,
    required this.expeditionProgress,
    required this.hasPendingEventResult,
    required this.lastActivitySyncPresent,
    required this.totalAcceptedSteps,
    required this.hasSuccessfulActivitySync,
    required this.resolvedEventCount,
    required List<String> completedMilestones,
    required String firstJourneyStage,
    required this.firstJourneyComplete,
    required String homeServerTime,
    required String platformServerTime,
    required this.durationMs,
  }) : contentVersion = _identifierText(contentVersion, 'contentVersion'),
       currentNodeId = _identifierText(currentNodeId, 'currentNodeId'),
       expeditionStatus = _oneOf(
         expeditionStatus,
         'expeditionStatus',
         const <String>{'IN_PROGRESS', 'EVENT_READY', 'COMPLETED'},
       ),
       completedMilestones = List<String>.unmodifiable(
         completedMilestones.map(
           (String value) =>
               _oneOf(value, 'completedMilestones[]', _firstJourneyMilestones),
         ),
       ),
       firstJourneyStage = _oneOf(
         firstJourneyStage,
         'firstJourneyStage',
         const <String>{
           'welcome',
           'activity',
           'pet',
           'expedition',
           'event',
           'complete',
         },
       ),
       homeServerTime = _timestampText(homeServerTime, 'homeServerTime'),
       platformServerTime = _timestampText(
         platformServerTime,
         'platformServerTime',
       ) {
    _nonNegative(<String, int>{
      'homeActivityStateVersion': homeActivityStateVersion,
      'homeEconomyVersion': homeEconomyVersion,
      'platformStateVersion': platformStateVersion,
      'dailySteps': dailySteps,
      'dailyGoal': dailyGoal,
      'availableEnergy': availableEnergy,
      'expeditionProgress': expeditionProgress,
      'totalAcceptedSteps': totalAcceptedSteps,
      'resolvedEventCount': resolvedEventCount,
    });
    if (this.completedMilestones.length > 16) {
      throw const FormatException('Слишком много milestone facts');
    }
    if (this.completedMilestones.toSet().length !=
        this.completedMilestones.length) {
      throw const FormatException('Milestone facts не должны повторяться');
    }
    final Set<String> milestoneSet = this.completedMilestones.toSet();
    final List<String> canonicalMilestones = _firstJourneyMilestoneOrder
        .where(milestoneSet.contains)
        .toList(growable: false);
    if (!_sameStrings(this.completedMilestones, canonicalMilestones)) {
      throw const FormatException('Milestone facts должны быть ordered');
    }
    if (_firstJourneyStageFor(milestoneSet) != this.firstJourneyStage) {
      throw const FormatException(
        'Milestone facts не соответствуют firstJourneyStage',
      );
    }
    if (firstJourneyComplete != (this.firstJourneyStage == 'complete')) {
      throw const FormatException(
        'firstJourneyComplete не соответствует firstJourneyStage',
      );
    }
    final bool durableActivitySync =
        lastActivitySyncPresent || hasSuccessfulActivitySync;
    if (milestoneSet.contains('health-permission') != durableActivitySync ||
        milestoneSet.contains('first-sync') != durableActivitySync) {
      throw const FormatException(
        'Activity milestone facts не соответствуют authoritative sync facts',
      );
    }
    if (milestoneSet.contains('first-event') &&
        !milestoneSet.contains('first-expedition')) {
      throw const FormatException(
        'first-event требует first-expedition milestone',
      );
    }
    final bool factBackedFirstEvent =
        resolvedEventCount > 0 ||
        this.currentNodeId != 'outer-beacon' ||
        this.expeditionStatus == 'COMPLETED';
    if (factBackedFirstEvent &&
        (!milestoneSet.contains('first-expedition') ||
            !milestoneSet.contains('first-event'))) {
      throw const FormatException(
        'Journey milestone facts не соответствуют authoritative event facts',
      );
    }
    _duration(durationMs);
  }

  final int homeActivityStateVersion;
  final int homeEconomyVersion;
  final int platformStateVersion;
  final String contentVersion;
  final int dailySteps;
  final int dailyGoal;
  final int availableEnergy;
  final String currentNodeId;
  final String expeditionStatus;
  final int expeditionProgress;
  final bool hasPendingEventResult;
  final bool lastActivitySyncPresent;
  final int totalAcceptedSteps;
  final bool hasSuccessfulActivitySync;
  final int resolvedEventCount;
  final List<String> completedMilestones;
  final String firstJourneyStage;
  final bool firstJourneyComplete;
  final String homeServerTime;
  final String platformServerTime;
  final int durationMs;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'homeActivityStateVersion': homeActivityStateVersion,
      'homeEconomyVersion': homeEconomyVersion,
      'platformStateVersion': platformStateVersion,
      'contentVersion': contentVersion,
      'dailySteps': dailySteps,
      'dailyGoal': dailyGoal,
      'availableEnergy': availableEnergy,
      'currentNodeId': currentNodeId,
      'expeditionStatus': expeditionStatus,
      'expeditionProgress': expeditionProgress,
      'hasPendingEventResult': hasPendingEventResult,
      'lastActivitySyncPresent': lastActivitySyncPresent,
      'totalAcceptedSteps': totalAcceptedSteps,
      'hasSuccessfulActivitySync': hasSuccessfulActivitySync,
      'resolvedEventCount': resolvedEventCount,
      'completedMilestones': completedMilestones,
      'firstJourneyStage': firstJourneyStage,
      'firstJourneyComplete': firstJourneyComplete,
      'homeServerTime': homeServerTime,
      'platformServerTime': platformServerTime,
      'durationMs': durationMs,
    };
  }
}

final class EvidenceJournalEntry {
  EvidenceJournalEntry({
    required this.sequence,
    required this.scenario,
    required this.outcome,
    required DateTime startedAtUtc,
    required this.durationMs,
    this.errorCategory,
  }) : startedAtUtc = startedAtUtc.toUtc() {
    if (sequence <= 0) {
      throw ArgumentError.value(sequence, 'sequence', 'Должен быть > 0');
    }
    _duration(durationMs);
    if (outcome == EvidenceOutcome.passed && errorCategory != null) {
      throw const FormatException('Passed journal entry не содержит error');
    }
    if (outcome != EvidenceOutcome.passed && errorCategory == null) {
      throw const FormatException('Failed/blocked journal entry требует error');
    }
    if (outcome != EvidenceOutcome.passed &&
        _expectedJournalOutcome(scenario, errorCategory!) != outcome) {
      throw const FormatException(
        'Journal outcome/category не соответствуют scenario',
      );
    }
  }

  final int sequence;
  final EvidenceScenario scenario;
  final EvidenceOutcome outcome;
  final DateTime startedAtUtc;
  final int durationMs;
  final EvidenceErrorCategory? errorCategory;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sequence': sequence,
      'scenario': scenario.wireName,
      'outcome': outcome.wireName,
      'startedAtUtc': startedAtUtc.toIso8601String(),
      'durationMs': durationMs,
      'errorCategory': errorCategory?.wireName,
    };
  }
}

final class DeviceValidationEvidenceSnapshot {
  DeviceValidationEvidenceSnapshot({
    required this.launch,
    required DateTime updatedAtUtc,
    required List<EvidenceJournalEntry> journal,
    this.latestHealth,
    this.latestSync,
    this.authoritativeCheckpoint,
  }) : updatedAtUtc = updatedAtUtc.toUtc(),
       journal = List<EvidenceJournalEntry>.unmodifiable(journal) {
    if (this.journal.length > DeviceValidationEvidenceCodec.maxJournalEntries) {
      throw const EvidenceLimitException('Journal превышает 64 entries');
    }
    if (this.updatedAtUtc.isBefore(launch.startedAtUtc)) {
      throw const FormatException('updatedAtUtc предшествует launch');
    }
    DateTime previousStartedAtUtc = launch.startedAtUtc;
    bool limitMarkerSeen = false;
    for (int index = 0; index < this.journal.length; index += 1) {
      if (this.journal[index].sequence != index + 1) {
        throw const FormatException(
          'Journal sequence должен быть непрерывным и начинаться с 1',
        );
      }
      if (this.journal[index].startedAtUtc.isBefore(launch.startedAtUtc) ||
          this.journal[index].startedAtUtc.isAfter(this.updatedAtUtc)) {
        throw const FormatException(
          'Journal timestamp находится вне launch/update interval',
        );
      }
      if (this.journal[index].startedAtUtc.isBefore(previousStartedAtUtc)) {
        throw const FormatException(
          'Journal timestamps должны быть монотонны по sequence',
        );
      }
      previousStartedAtUtc = this.journal[index].startedAtUtc;
      if (this.journal[index].errorCategory ==
          EvidenceErrorCategory.journalLimitReached) {
        if (limitMarkerSeen || index != this.journal.length - 1) {
          throw const FormatException(
            'journal_limit_reached должен быть единственным terminal marker',
          );
        }
        final EvidenceJournalEntry marker = this.journal[index];
        final bool capacityDerived =
            marker.durationMs == 0 &&
            (marker.scenario == EvidenceScenario.read
                ? marker.sequence >=
                      DeviceValidationEvidenceCodec.maxJournalEntries - 2
                : marker.sequence ==
                      DeviceValidationEvidenceCodec.maxJournalEntries);
        if (!capacityDerived) {
          throw const FormatException(
            'journal_limit_reached не соответствует reserved capacity',
          );
        }
        limitMarkerSeen = true;
      }
    }
    if (this.journal.length ==
            DeviceValidationEvidenceCodec.maxJournalEntries &&
        !limitMarkerSeen) {
      throw const EvidenceLimitException(
        '64-я journal entry зарезервирована для terminal marker',
      );
    }
    _validateJournalLifecycle(this.journal);
    _validateSnapshotSemantics(
      launch: launch,
      latestHealth: latestHealth,
      latestSync: latestSync,
      authoritativeCheckpoint: authoritativeCheckpoint,
      journal: this.journal,
    );
  }

  final EvidenceLaunchMetadata launch;
  final DateTime updatedAtUtc;
  final EvidenceHealthObservation? latestHealth;
  final EvidenceSyncObservation? latestSync;
  final AuthoritativeJourneyFacts? authoritativeCheckpoint;
  final List<EvidenceJournalEntry> journal;
}

void _validateSnapshotSemantics({
  required EvidenceLaunchMetadata launch,
  required EvidenceHealthObservation? latestHealth,
  required EvidenceSyncObservation? latestSync,
  required AuthoritativeJourneyFacts? authoritativeCheckpoint,
  required List<EvidenceJournalEntry> journal,
}) {
  final int healthIndex = _lastRelevantJournalIndex(
    journal,
    (EvidenceJournalEntry entry) =>
        entry.scenario == EvidenceScenario.provider ||
        entry.scenario == EvidenceScenario.permission ||
        entry.scenario == EvidenceScenario.read,
  );
  if ((healthIndex < 0) != (latestHealth == null)) {
    throw const FormatException(
      'Latest Health observation не соответствует journal lifecycle',
    );
  }
  if (latestHealth != null) {
    final EvidenceJournalEntry healthEntry = journal[healthIndex];
    if (latestHealth.status == EvidenceObservationStatus.succeeded) {
      final bool development =
          launch.healthSource == EvidenceHealthSource.development;
      final bool developmentObservation =
          latestHealth.providerState == EvidenceProviderState.notApplicable &&
          latestHealth.permissionState == EvidencePermissionState.notRequired;
      if (development != developmentObservation) {
        throw const FormatException(
          'Health observation не соответствует launch health source',
        );
      }
      if (healthEntry.scenario != EvidenceScenario.read) {
        throw const FormatException(
          'Успешное Health observation требует terminal read entry',
        );
      }
    }
    if (!_entryMatchesObservation(
      healthEntry,
      status: latestHealth.status,
      durationMs: latestHealth.durationMs,
      errorCategory: latestHealth.errorCategory,
    )) {
      throw const FormatException('Latest Health observation устарело');
    }
    _validateHealthTerminalGroup(journal, healthIndex, latestHealth);
  }

  final int syncIndex = _lastRelevantJournalIndex(
    journal,
    (EvidenceJournalEntry entry) => entry.scenario == EvidenceScenario.sync,
  );
  if ((syncIndex < 0) != (latestSync == null)) {
    throw const FormatException(
      'Latest sync observation не соответствует journal lifecycle',
    );
  }
  if (latestSync != null) {
    if (!_entryMatchesObservation(
      journal[syncIndex],
      status: latestSync.status,
      durationMs: latestSync.durationMs,
      errorCategory: latestSync.errorCategory,
    )) {
      throw const FormatException('Latest sync observation устарело');
    }
    if (latestSync.status == EvidenceObservationStatus.succeeded) {
      final int precedingHealthIndex = _lastRelevantJournalIndex(
        journal,
        (EvidenceJournalEntry entry) =>
            entry.scenario == EvidenceScenario.provider ||
            entry.scenario == EvidenceScenario.permission ||
            entry.scenario == EvidenceScenario.read,
        endExclusive: syncIndex,
      );
      if (precedingHealthIndex < 0 ||
          journal[precedingHealthIndex].scenario != EvidenceScenario.read ||
          journal[precedingHealthIndex].outcome != EvidenceOutcome.passed) {
        throw const FormatException('Успешный sync требует latest passed read');
      }
    }
  }

  final int checkpointIndex = _lastRelevantJournalIndex(
    journal,
    (EvidenceJournalEntry entry) =>
        entry.scenario == EvidenceScenario.checkpoint,
  );
  final EvidenceJournalEntry? checkpointEntry = checkpointIndex < 0
      ? null
      : journal[checkpointIndex];
  final bool checkpointPassed =
      checkpointEntry?.outcome == EvidenceOutcome.passed;
  if (checkpointPassed != (authoritativeCheckpoint != null)) {
    throw const FormatException(
      'Authoritative checkpoint не соответствует latest journal entry',
    );
  }
  if (authoritativeCheckpoint != null &&
      checkpointEntry!.durationMs != authoritativeCheckpoint.durationMs) {
    throw const FormatException('Authoritative checkpoint устарел');
  }
}

void _validateJournalLifecycle(List<EvidenceJournalEntry> journal) {
  for (int index = 0; index < journal.length; index += 1) {
    final EvidenceJournalEntry entry = journal[index];
    if (entry.errorCategory == EvidenceErrorCategory.journalLimitReached) {
      continue;
    }
    switch (entry.scenario) {
      case EvidenceScenario.provider:
        if (entry.outcome == EvidenceOutcome.passed) {
          _requireHealthPhase(
            journal,
            index + 1,
            EvidenceScenario.permission,
            entry.startedAtUtc,
          );
        }
        break;
      case EvidenceScenario.permission:
        _requirePassedHealthPhase(
          journal,
          index - 1,
          EvidenceScenario.provider,
          entry.startedAtUtc,
        );
        if (entry.outcome == EvidenceOutcome.passed) {
          _requireHealthPhase(
            journal,
            index + 1,
            EvidenceScenario.read,
            entry.startedAtUtc,
          );
        }
        break;
      case EvidenceScenario.read:
        if (entry.errorCategory == EvidenceErrorCategory.unexpectedFailure) {
          if (index > 0) {
            final EvidenceJournalEntry previous = journal[index - 1];
            if (previous.scenario == EvidenceScenario.permission &&
                previous.outcome == EvidenceOutcome.passed &&
                previous.startedAtUtc == entry.startedAtUtc) {
              throw const FormatException(
                'unexpected Health failure не может подтверждать passed phases',
              );
            }
          }
        } else {
          _requirePassedHealthPhase(
            journal,
            index - 2,
            EvidenceScenario.provider,
            entry.startedAtUtc,
          );
          _requirePassedHealthPhase(
            journal,
            index - 1,
            EvidenceScenario.permission,
            entry.startedAtUtc,
          );
        }
        break;
      case EvidenceScenario.sync:
        if (entry.outcome == EvidenceOutcome.passed) {
          final int precedingHealthIndex = _lastRelevantJournalIndex(
            journal,
            (EvidenceJournalEntry candidate) =>
                candidate.scenario == EvidenceScenario.provider ||
                candidate.scenario == EvidenceScenario.permission ||
                candidate.scenario == EvidenceScenario.read,
            endExclusive: index,
          );
          if (precedingHealthIndex < 0 ||
              journal[precedingHealthIndex].scenario != EvidenceScenario.read ||
              journal[precedingHealthIndex].outcome != EvidenceOutcome.passed) {
            throw const FormatException(
              'Успешный sync требует latest passed Health read group',
            );
          }
        }
        break;
      case EvidenceScenario.checkpoint:
        break;
    }
  }
}

void _requireHealthPhase(
  List<EvidenceJournalEntry> journal,
  int index,
  EvidenceScenario scenario,
  DateTime startedAtUtc,
) {
  if (index < 0 || index >= journal.length) {
    throw const FormatException('Health journal lifecycle неполон');
  }
  final EvidenceJournalEntry entry = journal[index];
  if (entry.scenario != scenario ||
      entry.errorCategory == EvidenceErrorCategory.journalLimitReached ||
      entry.startedAtUtc != startedAtUtc) {
    throw const FormatException('Health journal lifecycle нарушен');
  }
}

void _validateHealthTerminalGroup(
  List<EvidenceJournalEntry> journal,
  int terminalIndex,
  EvidenceHealthObservation observation,
) {
  final EvidenceJournalEntry terminal = journal[terminalIndex];
  if (terminal.scenario == EvidenceScenario.provider) {
    return;
  }
  if (terminal.scenario == EvidenceScenario.permission) {
    _requirePassedHealthPhase(
      journal,
      terminalIndex - 1,
      EvidenceScenario.provider,
      terminal.startedAtUtc,
    );
    return;
  }
  final bool unknownPhaseFailure =
      observation.status == EvidenceObservationStatus.failed &&
      observation.errorCategory == EvidenceErrorCategory.unexpectedFailure &&
      observation.providerState == EvidenceProviderState.unknown &&
      observation.permissionState == EvidencePermissionState.unknown;
  if (unknownPhaseFailure) {
    return;
  }
  _requirePassedHealthPhase(
    journal,
    terminalIndex - 2,
    EvidenceScenario.provider,
    terminal.startedAtUtc,
  );
  _requirePassedHealthPhase(
    journal,
    terminalIndex - 1,
    EvidenceScenario.permission,
    terminal.startedAtUtc,
  );
}

void _requirePassedHealthPhase(
  List<EvidenceJournalEntry> journal,
  int index,
  EvidenceScenario scenario,
  DateTime startedAtUtc,
) {
  if (index < 0 || index >= journal.length) {
    throw const FormatException('Health journal lifecycle неполон');
  }
  final EvidenceJournalEntry entry = journal[index];
  if (entry.scenario != scenario ||
      entry.outcome != EvidenceOutcome.passed ||
      entry.durationMs != 0 ||
      entry.startedAtUtc != startedAtUtc) {
    throw const FormatException('Health journal lifecycle нарушен');
  }
}

int _lastRelevantJournalIndex(
  List<EvidenceJournalEntry> journal,
  bool Function(EvidenceJournalEntry entry) matchesScenario, {
  int? endExclusive,
}) {
  final int upperBound = endExclusive ?? journal.length;
  for (int index = upperBound - 1; index >= 0; index -= 1) {
    final EvidenceJournalEntry entry = journal[index];
    if (matchesScenario(entry) &&
        entry.errorCategory != EvidenceErrorCategory.journalLimitReached) {
      return index;
    }
  }
  return -1;
}

bool _entryMatchesObservation(
  EvidenceJournalEntry entry, {
  required EvidenceObservationStatus status,
  required int durationMs,
  required EvidenceErrorCategory? errorCategory,
}) {
  final EvidenceOutcome expectedOutcome = switch (status) {
    EvidenceObservationStatus.succeeded => EvidenceOutcome.passed,
    EvidenceObservationStatus.failed => EvidenceOutcome.failed,
    EvidenceObservationStatus.blocked => EvidenceOutcome.blocked,
  };
  return entry.outcome == expectedOutcome &&
      entry.durationMs == durationMs &&
      entry.errorCategory == errorCategory;
}

abstract final class DeviceValidationEvidenceCodec {
  static const String schemaVersion =
      'walking-rpg-device-validation-evidence-v1';
  static const String redactionPolicy = 'walking-rpg-evidence-redaction-v1';
  static const int maxJournalEntries = 64;
  static const int maxEncodedBytes = 64 * 1024;
  static const List<String> _envelopeKeys = <String>[
    'schemaVersion',
    'redactionPolicy',
    'exportedAtUtc',
    'updatedAtUtc',
    'launch',
    'latestHealth',
    'latestSync',
    'authoritativeCheckpoint',
    'journal',
    'checksum',
  ];

  static String encode(
    DeviceValidationEvidenceSnapshot snapshot, {
    required DateTime exportedAtUtc,
  }) {
    final DateTime normalizedExportedAtUtc = exportedAtUtc.toUtc();
    if (normalizedExportedAtUtc.isBefore(snapshot.updatedAtUtc)) {
      throw const FormatException('exportedAtUtc предшествует updatedAtUtc');
    }
    final Map<String, Object?> payload = <String, Object?>{
      'schemaVersion': schemaVersion,
      'redactionPolicy': redactionPolicy,
      'exportedAtUtc': normalizedExportedAtUtc.toIso8601String(),
      'updatedAtUtc': snapshot.updatedAtUtc.toIso8601String(),
      'launch': snapshot.launch.toJson(),
      'latestHealth': snapshot.latestHealth?.toJson(),
      'latestSync': snapshot.latestSync?.toJson(),
      'authoritativeCheckpoint': snapshot.authoritativeCheckpoint?.toJson(),
      'journal': snapshot.journal
          .map((EvidenceJournalEntry entry) => entry.toJson())
          .toList(growable: false),
    };
    _validateRedaction(payload);
    final String checksum = sha256
        .convert(utf8.encode(jsonEncode(payload)))
        .toString();
    final Map<String, Object?> envelope = <String, Object?>{
      ...payload,
      'checksum': <String, Object?>{'algorithm': 'SHA-256', 'value': checksum},
    };
    final String encoded = jsonEncode(envelope);
    if (utf8.encode(encoded).length > maxEncodedBytes) {
      throw const EvidenceLimitException('Evidence JSON превышает 64 KiB');
    }
    return encoded;
  }

  static bool verify(String encoded) {
    try {
      return _verify(encoded);
    } on Object {
      return false;
    }
  }

  static bool _verify(String encoded) {
    if (utf8.encode(encoded).length > maxEncodedBytes) {
      return false;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return false;
    }
    if (decoded is! Map<String, dynamic>) {
      return false;
    }
    if (encoded != jsonEncode(decoded) ||
        !_hasKeyOrder(decoded, _envelopeKeys)) {
      return false;
    }
    final Map<String, dynamic> envelope = Map<String, dynamic>.of(decoded);
    if (envelope['schemaVersion'] != schemaVersion ||
        envelope['redactionPolicy'] != redactionPolicy) {
      return false;
    }
    final Object? rawChecksum = envelope.remove('checksum');
    if (rawChecksum is! Map<String, dynamic> ||
        !_hasKeyOrder(rawChecksum, const <String>['algorithm', 'value']) ||
        rawChecksum['algorithm'] != 'SHA-256') {
      return false;
    }
    final Object? expected = rawChecksum['value'];
    if (expected is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(expected)) {
      return false;
    }
    try {
      _validateSchemaShape(envelope);
      _validateRedaction(envelope);
    } on Object {
      return false;
    }
    final String actual = sha256
        .convert(utf8.encode(jsonEncode(envelope)))
        .toString();
    return actual == expected;
  }

  static void validateNoSensitiveData(Map<String, Object?> value) {
    _validateRedaction(value);
  }

  static bool _hasKeyOrder(Map<String, dynamic> value, List<String> expected) {
    if (value.length != expected.length) {
      return false;
    }
    final List<String> actual = value.keys.toList(growable: false);
    for (int index = 0; index < expected.length; index += 1) {
      if (actual[index] != expected[index]) {
        return false;
      }
    }
    return true;
  }

  static void _validateSchemaShape(Map<String, dynamic> payload) {
    final DateTime exportedAtUtc = _requiredUtcDate(payload, 'exportedAtUtc');
    final DateTime updatedAtUtc = _requiredUtcDate(payload, 'updatedAtUtc');
    if (exportedAtUtc.isBefore(updatedAtUtc)) {
      throw const FormatException('exportedAtUtc предшествует updatedAtUtc');
    }
    final Map<String, dynamic> launch = _requireMap(payload['launch']);
    _requireExactKeys(launch, const <String>[
      'startedAtUtc',
      'platform',
      'operatingSystemVersion',
      'appVersion',
      'buildNumber',
      'sourceGitSha',
      'buildMode',
      'authenticationMode',
      'healthSource',
    ]);
    final EvidenceLaunchMetadata launchMetadata = EvidenceLaunchMetadata(
      startedAtUtc: _requiredUtcDate(launch, 'startedAtUtc'),
      platform: _requiredString(launch, 'platform'),
      operatingSystemVersion: _requiredString(launch, 'operatingSystemVersion'),
      appVersion: _requiredString(launch, 'appVersion'),
      buildNumber: _requiredString(launch, 'buildNumber'),
      sourceGitSha: _requiredString(launch, 'sourceGitSha'),
      buildMode: _requiredString(launch, 'buildMode'),
      authenticationMode: _requiredString(launch, 'authenticationMode'),
      healthSource: _wireEnum<EvidenceHealthSource>(
        launch['healthSource'],
        'healthSource',
        EvidenceHealthSource.values,
        (EvidenceHealthSource value) => value.wireName,
      ),
    );

    final Map<String, dynamic>? health =
        _requireOptionalExactMap(payload['latestHealth'], const <String>[
          'status',
          'providerState',
          'permissionState',
          'authoritativeTotal',
          'localDate',
          'timeZone',
          'includeManualEntries',
          'durationMs',
          'errorCategory',
        ]);
    final EvidenceHealthObservation? healthObservation;
    if (health != null) {
      healthObservation = EvidenceHealthObservation(
        status: _wireEnum<EvidenceObservationStatus>(
          health['status'],
          'latestHealth.status',
          EvidenceObservationStatus.values,
          (EvidenceObservationStatus value) => value.wireName,
        ),
        providerState: _wireEnum<EvidenceProviderState>(
          health['providerState'],
          'latestHealth.providerState',
          EvidenceProviderState.values,
          (EvidenceProviderState value) => value.wireName,
        ),
        permissionState: _wireEnum<EvidencePermissionState>(
          health['permissionState'],
          'latestHealth.permissionState',
          EvidencePermissionState.values,
          (EvidencePermissionState value) => value.wireName,
        ),
        authoritativeTotal: _optionalInt(health, 'authoritativeTotal'),
        localDate: _optionalString(health, 'localDate'),
        timeZone: _optionalString(health, 'timeZone'),
        includeManualEntries: _requiredBool(health, 'includeManualEntries'),
        durationMs: _requiredInt(health, 'durationMs'),
        errorCategory: _nullableWireEnum<EvidenceErrorCategory>(
          health['errorCategory'],
          'latestHealth.errorCategory',
          EvidenceErrorCategory.values,
          (EvidenceErrorCategory value) => value.wireName,
        ),
      );
    } else {
      healthObservation = null;
    }

    final Map<String, dynamic>? sync =
        _requireOptionalExactMap(payload['latestSync'], const <String>[
          'status',
          'acceptedTotal',
          'acceptedDelta',
          'energyGranted',
          'energyBalanceAfter',
          'economyVersion',
          'stateVersion',
          'riskStatus',
          'serverTime',
          'durationMs',
          'errorCategory',
        ]);
    final EvidenceSyncObservation? syncObservation;
    if (sync != null) {
      final EvidenceObservationStatus status =
          _wireEnum<EvidenceObservationStatus>(
            sync['status'],
            'latestSync.status',
            EvidenceObservationStatus.values,
            (EvidenceObservationStatus value) => value.wireName,
          );
      final EvidenceErrorCategory? errorCategory =
          _nullableWireEnum<EvidenceErrorCategory>(
            sync['errorCategory'],
            'latestSync.errorCategory',
            EvidenceErrorCategory.values,
            (EvidenceErrorCategory value) => value.wireName,
          );
      if (status == EvidenceObservationStatus.succeeded) {
        if (errorCategory != null) {
          throw const FormatException(
            'Успешный sync не содержит error category',
          );
        }
        syncObservation = EvidenceSyncObservation.succeeded(
          acceptedTotal: _requiredInt(sync, 'acceptedTotal'),
          acceptedDelta: _requiredInt(sync, 'acceptedDelta'),
          energyGranted: _requiredInt(sync, 'energyGranted'),
          energyBalanceAfter: _requiredInt(sync, 'energyBalanceAfter'),
          economyVersion: _requiredInt(sync, 'economyVersion'),
          stateVersion: _requiredInt(sync, 'stateVersion'),
          riskStatus: _requiredString(sync, 'riskStatus'),
          serverTime: _requiredString(sync, 'serverTime'),
          durationMs: _requiredInt(sync, 'durationMs'),
        );
      } else {
        if (errorCategory == null) {
          throw const FormatException('Неуспешный sync требует error category');
        }
        _requireNullFields(sync, const <String>[
          'acceptedTotal',
          'acceptedDelta',
          'energyGranted',
          'energyBalanceAfter',
          'economyVersion',
          'stateVersion',
          'riskStatus',
          'serverTime',
        ]);
        syncObservation = EvidenceSyncObservation.unsuccessful(
          status: status,
          durationMs: _requiredInt(sync, 'durationMs'),
          errorCategory: errorCategory,
        );
      }
    } else {
      syncObservation = null;
    }

    final Map<String, dynamic>? checkpoint = _requireOptionalExactMap(
      payload['authoritativeCheckpoint'],
      const <String>[
        'homeActivityStateVersion',
        'homeEconomyVersion',
        'platformStateVersion',
        'contentVersion',
        'dailySteps',
        'dailyGoal',
        'availableEnergy',
        'currentNodeId',
        'expeditionStatus',
        'expeditionProgress',
        'hasPendingEventResult',
        'lastActivitySyncPresent',
        'totalAcceptedSteps',
        'hasSuccessfulActivitySync',
        'resolvedEventCount',
        'completedMilestones',
        'firstJourneyStage',
        'firstJourneyComplete',
        'homeServerTime',
        'platformServerTime',
        'durationMs',
      ],
    );
    final AuthoritativeJourneyFacts? checkpointFacts;
    if (checkpoint != null) {
      checkpointFacts = AuthoritativeJourneyFacts(
        homeActivityStateVersion: _requiredInt(
          checkpoint,
          'homeActivityStateVersion',
        ),
        homeEconomyVersion: _requiredInt(checkpoint, 'homeEconomyVersion'),
        platformStateVersion: _requiredInt(checkpoint, 'platformStateVersion'),
        contentVersion: _requiredString(checkpoint, 'contentVersion'),
        dailySteps: _requiredInt(checkpoint, 'dailySteps'),
        dailyGoal: _requiredInt(checkpoint, 'dailyGoal'),
        availableEnergy: _requiredInt(checkpoint, 'availableEnergy'),
        currentNodeId: _requiredString(checkpoint, 'currentNodeId'),
        expeditionStatus: _requiredString(checkpoint, 'expeditionStatus'),
        expeditionProgress: _requiredInt(checkpoint, 'expeditionProgress'),
        hasPendingEventResult: _requiredBool(
          checkpoint,
          'hasPendingEventResult',
        ),
        lastActivitySyncPresent: _requiredBool(
          checkpoint,
          'lastActivitySyncPresent',
        ),
        totalAcceptedSteps: _requiredInt(checkpoint, 'totalAcceptedSteps'),
        hasSuccessfulActivitySync: _requiredBool(
          checkpoint,
          'hasSuccessfulActivitySync',
        ),
        resolvedEventCount: _requiredInt(checkpoint, 'resolvedEventCount'),
        completedMilestones: _requiredStringList(
          checkpoint,
          'completedMilestones',
        ),
        firstJourneyStage: _requiredString(checkpoint, 'firstJourneyStage'),
        firstJourneyComplete: _requiredBool(checkpoint, 'firstJourneyComplete'),
        homeServerTime: _requiredString(checkpoint, 'homeServerTime'),
        platformServerTime: _requiredString(checkpoint, 'platformServerTime'),
        durationMs: _requiredInt(checkpoint, 'durationMs'),
      );
    } else {
      checkpointFacts = null;
    }

    final Object? rawJournal = payload['journal'];
    if (rawJournal is! List<Object?> || rawJournal.length > maxJournalEntries) {
      throw const FormatException('Некорректный evidence journal');
    }
    final List<EvidenceJournalEntry> journal = <EvidenceJournalEntry>[];
    for (int index = 0; index < rawJournal.length; index += 1) {
      final Map<String, dynamic> entry = _requireMap(rawJournal[index]);
      _requireExactKeys(entry, const <String>[
        'sequence',
        'scenario',
        'outcome',
        'startedAtUtc',
        'durationMs',
        'errorCategory',
      ]);
      if (entry['sequence'] != index + 1) {
        throw const FormatException('Некорректная journal sequence');
      }
      journal.add(
        EvidenceJournalEntry(
          sequence: _requiredInt(entry, 'sequence'),
          scenario: _wireEnum<EvidenceScenario>(
            entry['scenario'],
            'journal.scenario',
            EvidenceScenario.values,
            (EvidenceScenario value) => value.wireName,
          ),
          outcome: _wireEnum<EvidenceOutcome>(
            entry['outcome'],
            'journal.outcome',
            EvidenceOutcome.values,
            (EvidenceOutcome value) => value.wireName,
          ),
          startedAtUtc: _requiredUtcDate(entry, 'startedAtUtc'),
          durationMs: _requiredInt(entry, 'durationMs'),
          errorCategory: _nullableWireEnum<EvidenceErrorCategory>(
            entry['errorCategory'],
            'journal.errorCategory',
            EvidenceErrorCategory.values,
            (EvidenceErrorCategory value) => value.wireName,
          ),
        ),
      );
    }
    DeviceValidationEvidenceSnapshot(
      launch: launchMetadata,
      updatedAtUtc: updatedAtUtc,
      latestHealth: healthObservation,
      latestSync: syncObservation,
      authoritativeCheckpoint: checkpointFacts,
      journal: journal,
    );
  }

  static Map<String, dynamic>? _requireOptionalExactMap(
    Object? value,
    List<String> expected,
  ) {
    if (value == null) {
      return null;
    }
    final Map<String, dynamic> map = _requireMap(value);
    _requireExactKeys(map, expected);
    return map;
  }

  static Map<String, dynamic> _requireMap(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Ожидался JSON object');
    }
    return value;
  }

  static void _requireExactKeys(
    Map<String, dynamic> value,
    List<String> expected,
  ) {
    if (!_hasKeyOrder(value, expected)) {
      throw const FormatException('Evidence содержит unknown/missing fields');
    }
  }

  static void _validateRedaction(Object? value, {String? key}) {
    final String? normalizedKey = key == null ? null : _normalizeKey(key);
    if (normalizedKey != null && _isForbiddenKey(normalizedKey)) {
      throw FormatException('Evidence содержит запрещённое поле $key');
    }
    if (value is Map<Object?, Object?>) {
      for (final MapEntry<Object?, Object?> entry in value.entries) {
        final Object? rawKey = entry.key;
        if (rawKey is! String) {
          throw const FormatException('Evidence keys должны быть строками');
        }
        _validateRedaction(entry.value, key: rawKey);
      }
      return;
    }
    if (value is Iterable<Object?>) {
      for (final Object? item in value) {
        _validateRedaction(item);
      }
      return;
    }
    if (value is String) {
      final bool ianaTimeZone =
          normalizedKey == 'timezone' && _isIanaTimeZone(value);
      final bool pathSeparator =
          !ianaTimeZone && (value.contains('/') || value.contains(r'\'));
      if (RegExp(
            r'[\x00-\x1f\x7f-\x9f\u200b-\u200f\u202a-\u202e\u2060\u2066-\u2069\ufeff]',
          ).hasMatch(value) ||
          RegExp(
            r'\bbearer\s+[a-z0-9._~+/=-]+',
            caseSensitive: false,
          ).hasMatch(value) ||
          RegExp(
            r'\beyj[a-z0-9_-]{5,}\.[a-z0-9_-]{5,}\.',
            caseSensitive: false,
          ).hasMatch(value) ||
          RegExp(r'(?:https?|file)://', caseSensitive: false).hasMatch(value) ||
          RegExp(
            r'\b(?:[a-z0-9-]+\.)+[a-z]{2,63}\b',
            caseSensitive: false,
          ).hasMatch(value) ||
          RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}(?::\d{1,5})?\b').hasMatch(value) ||
          RegExp(
            r'(?:^|[\s(])(?:\[[0-9a-f:]+\](?::\d{1,5})?|[0-9a-f]{0,4}:[0-9a-f:]*:[0-9a-f:]+)(?:$|[\s),])',
            caseSensitive: false,
          ).hasMatch(value) ||
          RegExp(
            r'\blocalhost(?::\d{1,5})?\b',
            caseSensitive: false,
          ).hasMatch(value) ||
          RegExp(r'\b[a-z]:[\\/]', caseSensitive: false).hasMatch(value) ||
          pathSeparator) {
        throw const FormatException(
          'Evidence содержит secret, endpoint или private path',
        );
      }
    }
  }

  static String _normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  }

  static bool _isForbiddenKey(String key) {
    if (_forbiddenKeys.contains(key) ||
        key.contains('token') ||
        key.contains('authorization') ||
        key.contains('cookie') ||
        key.contains('ownerid') ||
        key.contains('userid') ||
        key.contains('accountid') ||
        key.contains('subject') ||
        key.contains('deviceid') ||
        key.contains('installationid') ||
        key.contains('sourceid') ||
        key.contains('recordid') ||
        key.contains('commandid') ||
        key.contains('diagnosticid') ||
        key.contains('crashid') ||
        key.contains('synccursor') ||
        key.contains('idempotencykey') ||
        key.contains('endpoint') ||
        key.contains('hostname') ||
        key.contains('filepath') ||
        key.contains('stacktrace') ||
        key.contains('rawerror') ||
        key.contains('errormessage') ||
        key.contains('exception') ||
        key.contains('requestbody') ||
        key.contains('responsebody')) {
      return true;
    }
    if (key == 'errorcategory') {
      return false;
    }
    return false;
  }

  static const Set<String> _forbiddenKeys = <String>{
    'accesstoken',
    'refreshtoken',
    'idtoken',
    'authorization',
    'cookie',
    'issuer',
    'subject',
    'login',
    'displayname',
    'ownerid',
    'userid',
    'deviceid',
    'installationid',
    'synccursor',
    'idempotencykey',
    'apibaseurl',
    'endpoint',
    'url',
    'hostname',
    'path',
    'payload',
    'request',
    'response',
    'rawerror',
    'exception',
    'authorizationheader',
    'rawownerid',
    'apiendpoint',
    'errormessage',
  };
}

bool _isValidHealthFailure({
  required EvidenceObservationStatus status,
  required EvidenceProviderState providerState,
  required EvidencePermissionState permissionState,
  required EvidenceErrorCategory errorCategory,
}) {
  return switch (errorCategory) {
    EvidenceErrorCategory.unsupportedPlatform =>
      status == EvidenceObservationStatus.blocked &&
          providerState == EvidenceProviderState.unavailable &&
          permissionState == EvidencePermissionState.unknown,
    EvidenceErrorCategory.providerUpdateRequired =>
      status == EvidenceObservationStatus.blocked &&
          providerState == EvidenceProviderState.updateRequired &&
          permissionState == EvidencePermissionState.unknown,
    EvidenceErrorCategory.providerUnavailable =>
      status == EvidenceObservationStatus.blocked &&
          providerState == EvidenceProviderState.unavailable &&
          permissionState == EvidencePermissionState.unknown,
    EvidenceErrorCategory.permissionDenied =>
      status == EvidenceObservationStatus.failed &&
          providerState == EvidenceProviderState.available &&
          permissionState == EvidencePermissionState.denied,
    EvidenceErrorCategory.permissionSettingsRequired =>
      status == EvidenceObservationStatus.blocked &&
          providerState == EvidenceProviderState.available &&
          permissionState == EvidencePermissionState.settingsRequired,
    EvidenceErrorCategory.permissionRestricted =>
      status == EvidenceObservationStatus.blocked &&
          providerState == EvidenceProviderState.available &&
          permissionState == EvidencePermissionState.restricted,
    EvidenceErrorCategory.protectedDataUnavailable ||
    EvidenceErrorCategory.timeZoneUnavailable ||
    EvidenceErrorCategory.healthReadFailed =>
      status == EvidenceObservationStatus.failed &&
          providerState == EvidenceProviderState.available &&
          permissionState == EvidencePermissionState.requestSucceeded,
    EvidenceErrorCategory.unexpectedFailure =>
      status == EvidenceObservationStatus.failed &&
          providerState == EvidenceProviderState.unknown &&
          permissionState == EvidencePermissionState.unknown,
    _ => false,
  };
}

bool _isValidSyncFailure(
  EvidenceObservationStatus status,
  EvidenceErrorCategory errorCategory,
) {
  return switch (errorCategory) {
    EvidenceErrorCategory.readingRequired =>
      status == EvidenceObservationStatus.blocked,
    EvidenceErrorCategory.networkUnavailable ||
    EvidenceErrorCategory.reauthenticationRequired ||
    EvidenceErrorCategory.invalidResponse ||
    EvidenceErrorCategory.unexpectedFailure =>
      status == EvidenceObservationStatus.failed,
    _ => false,
  };
}

EvidenceOutcome? _expectedJournalOutcome(
  EvidenceScenario scenario,
  EvidenceErrorCategory errorCategory,
) {
  return switch (scenario) {
    EvidenceScenario.provider => switch (errorCategory) {
      EvidenceErrorCategory.unsupportedPlatform ||
      EvidenceErrorCategory.providerUpdateRequired ||
      EvidenceErrorCategory.providerUnavailable => EvidenceOutcome.blocked,
      _ => null,
    },
    EvidenceScenario.permission => switch (errorCategory) {
      EvidenceErrorCategory.permissionDenied => EvidenceOutcome.failed,
      EvidenceErrorCategory.permissionSettingsRequired ||
      EvidenceErrorCategory.permissionRestricted => EvidenceOutcome.blocked,
      _ => null,
    },
    EvidenceScenario.read => switch (errorCategory) {
      EvidenceErrorCategory.protectedDataUnavailable ||
      EvidenceErrorCategory.timeZoneUnavailable ||
      EvidenceErrorCategory.healthReadFailed ||
      EvidenceErrorCategory.unexpectedFailure => EvidenceOutcome.failed,
      EvidenceErrorCategory.journalLimitReached => EvidenceOutcome.blocked,
      _ => null,
    },
    EvidenceScenario.sync => switch (errorCategory) {
      EvidenceErrorCategory.readingRequired ||
      EvidenceErrorCategory.journalLimitReached => EvidenceOutcome.blocked,
      EvidenceErrorCategory.networkUnavailable ||
      EvidenceErrorCategory.reauthenticationRequired ||
      EvidenceErrorCategory.invalidResponse ||
      EvidenceErrorCategory.unexpectedFailure => EvidenceOutcome.failed,
      _ => null,
    },
    EvidenceScenario.checkpoint => switch (errorCategory) {
      EvidenceErrorCategory.cachedSnapshot ||
      EvidenceErrorCategory.journalLimitReached => EvidenceOutcome.blocked,
      EvidenceErrorCategory.networkUnavailable ||
      EvidenceErrorCategory.reauthenticationRequired ||
      EvidenceErrorCategory.invalidResponse ||
      EvidenceErrorCategory.unexpectedFailure => EvidenceOutcome.failed,
      _ => null,
    },
  };
}

final class EvidenceLimitException implements Exception {
  const EvidenceLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _safeText(String value, String field) {
  if (RegExp(
    r'[\x00-\x1f\x7f-\x9f\u200b-\u200f\u202a-\u202e\u2060\u2066-\u2069\ufeff]',
  ).hasMatch(value)) {
    throw FormatException('$field содержит control/bidi символы');
  }
  final String normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty || normalized.length > 160) {
    throw FormatException('$field должен содержать от 1 до 160 символов');
  }
  if (normalized != value) {
    throw FormatException('$field должен быть canonical без normalization');
  }
  DeviceValidationEvidenceCodec.validateNoSensitiveData(<String, Object?>{
    field: normalized,
  });
  return normalized;
}

String _requiredString(Map<String, dynamic> value, String field) {
  final Object? raw = value[field];
  if (raw is! String) {
    throw FormatException('$field должен быть строкой');
  }
  return raw;
}

String? _optionalString(Map<String, dynamic> value, String field) {
  final Object? raw = value[field];
  if (raw == null) {
    return null;
  }
  if (raw is! String) {
    throw FormatException('$field должен быть строкой или null');
  }
  return raw;
}

int _requiredInt(Map<String, dynamic> value, String field) {
  final Object? raw = value[field];
  if (raw is! int) {
    throw FormatException('$field должен быть integer');
  }
  return raw;
}

int? _optionalInt(Map<String, dynamic> value, String field) {
  final Object? raw = value[field];
  if (raw == null) {
    return null;
  }
  if (raw is! int) {
    throw FormatException('$field должен быть integer или null');
  }
  return raw;
}

bool _requiredBool(Map<String, dynamic> value, String field) {
  final Object? raw = value[field];
  if (raw is! bool) {
    throw FormatException('$field должен быть boolean');
  }
  return raw;
}

List<String> _requiredStringList(Map<String, dynamic> value, String field) {
  final Object? raw = value[field];
  if (raw is! List<Object?>) {
    throw FormatException('$field должен быть array');
  }
  return raw
      .map((Object? item) {
        if (item is! String) {
          throw FormatException('$field содержит нестроковое значение');
        }
        return item;
      })
      .toList(growable: false);
}

DateTime _requiredUtcDate(Map<String, dynamic> value, String field) {
  final String timestamp = _timestampText(_requiredString(value, field), field);
  return DateTime.parse(timestamp);
}

T _wireEnum<T>(
  Object? raw,
  String field,
  List<T> values,
  String Function(T value) wireName,
) {
  if (raw is! String) {
    throw FormatException('$field должен быть строковым enum');
  }
  for (final T value in values) {
    if (wireName(value) == raw) {
      return value;
    }
  }
  throw FormatException('$field содержит неизвестное enum значение');
}

T? _nullableWireEnum<T>(
  Object? raw,
  String field,
  List<T> values,
  String Function(T value) wireName,
) {
  if (raw == null) {
    return null;
  }
  return _wireEnum<T>(raw, field, values, wireName);
}

void _requireNullFields(Map<String, dynamic> value, List<String> fields) {
  for (final String field in fields) {
    if (value[field] != null) {
      throw FormatException('$field должен быть null для failed/blocked');
    }
  }
}

String _oneOf(String value, String field, Set<String> allowed) {
  final String normalized = _safeText(value, field);
  if (!allowed.contains(normalized)) {
    throw FormatException('$field содержит неизвестное значение');
  }
  return normalized;
}

String _identifierText(String value, String field) {
  final String normalized = _safeText(value, field);
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$').hasMatch(normalized)) {
    throw FormatException('$field не является безопасным identifier');
  }
  return normalized;
}

String _timestampText(String value, String field) {
  final String normalized = _safeText(value, field);
  final Match? match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
    r'(?:\.\d{1,6})?Z$',
  ).firstMatch(normalized);
  final DateTime? parsed = DateTime.tryParse(normalized);
  if (match == null ||
      parsed == null ||
      !parsed.isUtc ||
      parsed.year != int.parse(match.group(1)!) ||
      parsed.month != int.parse(match.group(2)!) ||
      parsed.day != int.parse(match.group(3)!) ||
      parsed.hour != int.parse(match.group(4)!) ||
      parsed.minute != int.parse(match.group(5)!) ||
      parsed.second != int.parse(match.group(6)!)) {
    throw FormatException('$field должен быть canonical RFC3339 UTC');
  }
  return normalized;
}

String? _optionalLocalDate(String? value) {
  if (value == null) {
    return null;
  }
  final String normalized = _safeText(value, 'localDate');
  final Match? match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(normalized);
  final DateTime? parsed = DateTime.tryParse('${normalized}T00:00:00Z');
  if (match == null ||
      parsed == null ||
      parsed.year.toString().padLeft(4, '0') != match.group(1) ||
      parsed.month.toString().padLeft(2, '0') != match.group(2) ||
      parsed.day.toString().padLeft(2, '0') != match.group(3)) {
    throw const FormatException('localDate должен быть календарной YYYY-MM-DD');
  }
  return normalized;
}

String? _optionalTimeZone(String? value) {
  if (value == null) {
    return null;
  }
  final String normalized = _safeText(value, 'timeZone');
  if (!_isIanaTimeZone(normalized)) {
    throw const FormatException('timeZone должен быть IANA identifier');
  }
  return normalized;
}

bool _isIanaTimeZone(String value) {
  final List<String> segments = value.split('/');
  if (segments.length == 1) {
    return _ianaTimeZoneAliases.contains(value);
  }
  if (!_ianaTimeZoneAreas.contains(segments.first)) {
    return false;
  }
  return segments
      .skip(1)
      .every(
        (String segment) =>
            RegExp(r'^[A-Z0-9][A-Za-z0-9_+-]*[A-Za-z0-9+-]$').hasMatch(segment),
      );
}

const Set<String> _ianaTimeZoneAreas = <String>{
  'Africa',
  'America',
  'Antarctica',
  'Arctic',
  'Asia',
  'Atlantic',
  'Australia',
  'Brazil',
  'Canada',
  'Chile',
  'Etc',
  'Europe',
  'Indian',
  'Mexico',
  'Pacific',
  'SystemV',
  'US',
};

const Set<String> _ianaTimeZoneAliases = <String>{
  'CET',
  'CST6CDT',
  'Cuba',
  'EET',
  'Egypt',
  'Eire',
  'EST',
  'EST5EDT',
  'Factory',
  'GB',
  'GB-Eire',
  'GMT',
  'GMT+0',
  'GMT-0',
  'GMT0',
  'Greenwich',
  'HST',
  'Hongkong',
  'Iceland',
  'Iran',
  'Israel',
  'Jamaica',
  'Japan',
  'Kwajalein',
  'Libya',
  'MET',
  'MST',
  'MST7MDT',
  'Navajo',
  'NZ',
  'NZ-CHAT',
  'Poland',
  'Portugal',
  'PRC',
  'PST8PDT',
  'ROC',
  'ROK',
  'Singapore',
  'Turkey',
  'UCT',
  'UTC',
  'Universal',
  'W-SU',
  'WET',
  'Zulu',
};

String _sourceSha(String value) {
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(value)) {
    throw const FormatException('sourceGitSha должен быть exact lowercase SHA');
  }
  return value;
}

void _duration(int value) {
  if (value < 0 || value > const Duration(days: 1).inMilliseconds) {
    throw ArgumentError.value(value, 'durationMs', 'Некорректная duration');
  }
}

void _nonNegative(Map<String, int> values) {
  for (final MapEntry<String, int> entry in values.entries) {
    if (entry.value < 0) {
      throw ArgumentError.value(
        entry.value,
        entry.key,
        'Значение не может быть отрицательным',
      );
    }
  }
}

const List<String> _firstJourneyMilestoneOrder = <String>[
  'welcome',
  'health-permission',
  'first-sync',
  'pet-selection',
  'first-expedition',
  'first-event',
];

const Set<String> _firstJourneyMilestones = <String>{
  'welcome',
  'health-permission',
  'first-sync',
  'pet-selection',
  'first-expedition',
  'first-event',
};

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (int index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

String _firstJourneyStageFor(Set<String> completed) {
  if (!completed.contains('welcome')) {
    return 'welcome';
  }
  if (!completed.contains('health-permission') ||
      !completed.contains('first-sync')) {
    return 'activity';
  }
  if (!completed.contains('pet-selection')) {
    return 'pet';
  }
  if (!completed.contains('first-expedition')) {
    return 'expedition';
  }
  if (!completed.contains('first-event')) {
    return 'event';
  }
  return 'complete';
}
