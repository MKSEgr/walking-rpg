import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/validation/validation_center_policy.dart';

void main() {
  const String sourceGitSha = '0123456789abcdef0123456789abcdef01234567';

  test('disabled validation center remains unavailable in release', () {
    expect(
      ValidationCenterPolicy.isEnabled(requested: false, releaseMode: true),
      isFalse,
    );
    expect(
      () => ValidationCenterPolicy.validate(
        requested: false,
        releaseMode: true,
        sourceGitSha: '',
      ),
      returnsNormally,
    );
  });

  test('explicit validation center request fails closed in release', () {
    expect(
      () => ValidationCenterPolicy.validate(
        requested: true,
        releaseMode: true,
        sourceGitSha: sourceGitSha,
      ),
      throwsA(isA<ValidationCenterConfigurationException>()),
    );
  });

  test('internal build requires exact source SHA', () {
    expect(
      () => ValidationCenterPolicy.validate(
        requested: true,
        releaseMode: false,
        sourceGitSha: 'unknown',
      ),
      throwsA(isA<ValidationCenterConfigurationException>()),
    );
  });

  test('valid internal build configuration enables the center', () {
    expect(
      ValidationCenterPolicy.isEnabled(requested: true, releaseMode: false),
      isTrue,
    );
    expect(
      () => ValidationCenterPolicy.validate(
        requested: true,
        releaseMode: false,
        sourceGitSha: sourceGitSha,
      ),
      returnsNormally,
    );
  });

  test('runtime package metadata must be present and bounded', () {
    expect(
      () => ValidationCenterPolicy.validateRuntimePackage(
        appVersion: '0.1.0',
        buildNumber: '46',
      ),
      returnsNormally,
    );
    expect(
      () => ValidationCenterPolicy.validateRuntimePackage(
        appVersion: '',
        buildNumber: '46',
      ),
      throwsA(isA<ValidationCenterConfigurationException>()),
    );
  });
}
