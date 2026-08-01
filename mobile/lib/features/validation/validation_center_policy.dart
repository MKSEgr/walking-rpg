import 'package:flutter/foundation.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';

abstract final class ValidationCenterPolicy {
  static bool get enabled => isEnabled(
    requested: AppEnvironment.enableValidationCenter,
    releaseMode: kReleaseMode,
  );

  static bool isEnabled({required bool requested, required bool releaseMode}) {
    return requested && !releaseMode;
  }

  static void validateEnvironment() {
    validate(
      requested: AppEnvironment.enableValidationCenter,
      releaseMode: kReleaseMode,
      sourceGitSha: AppEnvironment.validationSourceGitSha,
    );
  }

  static void validate({
    required bool requested,
    required bool releaseMode,
    required String sourceGitSha,
  }) {
    if (!requested) {
      return;
    }
    if (releaseMode) {
      throw const ValidationCenterConfigurationException(
        'Validation Center запрещён в production build',
      );
    }
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sourceGitSha)) {
      throw const ValidationCenterConfigurationException(
        'VALIDATION_SOURCE_GIT_SHA должен содержать exact 40-символьный '
        'lowercase Git SHA',
      );
    }
  }

  static void validateRuntimePackage({
    required String appVersion,
    required String buildNumber,
  }) {
    _requireBuildText(appVersion, 'runtime appVersion');
    _requireBuildText(buildNumber, 'runtime buildNumber');
  }

  static void _requireBuildText(String value, String field) {
    final String normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 64) {
      throw ValidationCenterConfigurationException(
        '$field должен содержать от 1 до 64 символов',
      );
    }
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(normalized)) {
      throw ValidationCenterConfigurationException(
        '$field содержит управляющие символы',
      );
    }
  }
}

final class ValidationCenterConfigurationException implements Exception {
  const ValidationCenterConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
