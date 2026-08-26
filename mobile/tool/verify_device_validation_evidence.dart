import 'dart:convert';
import 'dart:io';

import 'package:walking_rpg_mobile/features/validation/domain/device_validation_evidence.dart';

const String _usage = '''
Usage: dart run tool/verify_device_validation_evidence.dart [options] <evidence.json>

Options:
  --expect-source-git-sha <sha>  Require the exact lowercase 40-hex source SHA.
  --expect-app-version <value>   Require the exact installed app version.
  --expect-build-number <value>  Require the exact installed build number.
  --expect-platform <value>      Require ios or android.
  --require-physical-health      Reject development Health evidence and require
                                 all four exact candidate expectations above.
  --help                         Show this help.
''';

final class EvidenceVerifierOptions {
  const EvidenceVerifierOptions({
    required this.path,
    required this.requirePhysicalHealth,
    this.expectedSourceGitSha,
    this.expectedAppVersion,
    this.expectedBuildNumber,
    this.expectedPlatform,
  });

  final String path;
  final bool requirePhysicalHealth;
  final String? expectedSourceGitSha;
  final String? expectedAppVersion;
  final String? expectedBuildNumber;
  final String? expectedPlatform;
}

final class EvidenceVerifierUsageException implements Exception {
  const EvidenceVerifierUsageException();
}

final class EvidenceVerifierFailure implements Exception {
  const EvidenceVerifierFailure(this.message);

  final String message;
}

Future<void> main(List<String> arguments) async {
  exitCode = await runDeviceValidationEvidenceVerifier(arguments);
}

Future<int> runDeviceValidationEvidenceVerifier(
  List<String> arguments, {
  StringSink? output,
  StringSink? errorOutput,
}) async {
  final StringSink safeOutput = output ?? stdout;
  final StringSink safeError = errorOutput ?? stderr;
  if (arguments.length == 1 && arguments.single == '--help') {
    safeOutput.write(_usage);
    return 0;
  }

  try {
    final EvidenceVerifierOptions options = _parseArguments(arguments);
    final Map<String, dynamic> envelope = await _readAndVerify(options.path);
    final Map<String, dynamic> launch =
        envelope['launch']! as Map<String, dynamic>;
    _validateExpectations(options, launch);
    _validatePhysicalHealth(options, envelope, launch);
    _writeSummary(safeOutput, envelope, launch);
    return 0;
  } on EvidenceVerifierUsageException {
    safeError.write('Evidence verifier arguments are invalid.\n$_usage');
    return 2;
  } on EvidenceVerifierFailure catch (error) {
    safeError.writeln('Device validation evidence invalid: ${error.message}');
    return 1;
  } on Object {
    safeError.writeln(
      'Device validation evidence invalid: unexpected verification failure.',
    );
    return 1;
  }
}

EvidenceVerifierOptions _parseArguments(List<String> arguments) {
  if (arguments.isEmpty) {
    throw const EvidenceVerifierUsageException();
  }
  String? path;
  String? expectedSourceGitSha;
  String? expectedAppVersion;
  String? expectedBuildNumber;
  String? expectedPlatform;
  bool requirePhysicalHealth = false;
  final Set<String> seenOptions = <String>{};

  for (int index = 0; index < arguments.length; index += 1) {
    final String argument = arguments[index];
    if (argument == '--require-physical-health') {
      if (!seenOptions.add(argument)) {
        throw const EvidenceVerifierUsageException();
      }
      requirePhysicalHealth = true;
      continue;
    }
    if (_valueOptions.contains(argument)) {
      if (!seenOptions.add(argument) || index + 1 >= arguments.length) {
        throw const EvidenceVerifierUsageException();
      }
      final String value = arguments[index + 1];
      if (value.startsWith('--')) {
        throw const EvidenceVerifierUsageException();
      }
      index += 1;
      switch (argument) {
        case '--expect-source-git-sha':
          expectedSourceGitSha = value;
          break;
        case '--expect-app-version':
          expectedAppVersion = value;
          break;
        case '--expect-build-number':
          expectedBuildNumber = value;
          break;
        case '--expect-platform':
          expectedPlatform = value;
          break;
      }
      continue;
    }
    if (argument.startsWith('-') || path != null) {
      throw const EvidenceVerifierUsageException();
    }
    path = argument;
  }

  if (path == null || path.isEmpty) {
    throw const EvidenceVerifierUsageException();
  }
  if (expectedSourceGitSha != null &&
      (!RegExp(r'^[0-9a-f]{40}$').hasMatch(expectedSourceGitSha) ||
          expectedSourceGitSha == '0000000000000000000000000000000000000000')) {
    throw const EvidenceVerifierUsageException();
  }
  for (final String? value in <String?>[
    expectedAppVersion,
    expectedBuildNumber,
  ]) {
    if (value != null &&
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]{0,159}$').hasMatch(value)) {
      throw const EvidenceVerifierUsageException();
    }
  }
  if (expectedPlatform != null &&
      expectedPlatform != 'ios' &&
      expectedPlatform != 'android') {
    throw const EvidenceVerifierUsageException();
  }
  if (requirePhysicalHealth &&
      (expectedSourceGitSha == null ||
          expectedAppVersion == null ||
          expectedBuildNumber == null ||
          expectedPlatform == null)) {
    throw const EvidenceVerifierUsageException();
  }

  return EvidenceVerifierOptions(
    path: path,
    requirePhysicalHealth: requirePhysicalHealth,
    expectedSourceGitSha: expectedSourceGitSha,
    expectedAppVersion: expectedAppVersion,
    expectedBuildNumber: expectedBuildNumber,
    expectedPlatform: expectedPlatform,
  );
}

const Set<String> _valueOptions = <String>{
  '--expect-source-git-sha',
  '--expect-app-version',
  '--expect-build-number',
  '--expect-platform',
};

Future<Map<String, dynamic>> _readAndVerify(String path) async {
  final FileSystemEntityType type;
  try {
    type = await FileSystemEntity.type(path, followLinks: false);
  } on FileSystemException {
    throw const EvidenceVerifierFailure(
      'file is not a readable regular file.',
    );
  }
  if (type != FileSystemEntityType.file) {
    throw const EvidenceVerifierFailure('file must be a regular file.');
  }

  final File file = File(path);
  final FileStat stat;
  try {
    stat = await file.stat();
  } on FileSystemException {
    throw const EvidenceVerifierFailure(
      'file is not a readable regular file.',
    );
  }
  if (stat.size > DeviceValidationEvidenceCodec.maxEncodedBytes) {
    throw const EvidenceVerifierFailure('file exceeds the 64 KiB limit.');
  }

  final List<int> bytes;
  try {
    bytes = await file.readAsBytes();
  } on FileSystemException {
    throw const EvidenceVerifierFailure(
      'file is not a readable regular file.',
    );
  }
  if (bytes.length > DeviceValidationEvidenceCodec.maxEncodedBytes) {
    throw const EvidenceVerifierFailure('file exceeds the 64 KiB limit.');
  }

  final String encoded;
  try {
    encoded = utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    throw const EvidenceVerifierFailure('file is not strict UTF-8.');
  }
  if (!DeviceValidationEvidenceCodec.verify(encoded)) {
    throw const EvidenceVerifierFailure(
      'schema, redaction, canonical encoding or checksum verification failed.',
    );
  }
  final Object? decoded = jsonDecode(encoded);
  if (decoded is! Map<String, dynamic>) {
    throw const EvidenceVerifierFailure('schema verification failed.');
  }
  return decoded;
}

void _validateExpectations(
  EvidenceVerifierOptions options,
  Map<String, dynamic> launch,
) {
  final Map<String, String?> expectations = <String, String?>{
    'sourceGitSha': options.expectedSourceGitSha,
    'appVersion': options.expectedAppVersion,
    'buildNumber': options.expectedBuildNumber,
    'platform': options.expectedPlatform,
  };
  for (final MapEntry<String, String?> expectation in expectations.entries) {
    if (expectation.value != null &&
        launch[expectation.key] != expectation.value) {
      throw EvidenceVerifierFailure(
        '${expectation.key} does not match the expected candidate.',
      );
    }
  }
}

void _validatePhysicalHealth(
  EvidenceVerifierOptions options,
  Map<String, dynamic> envelope,
  Map<String, dynamic> launch,
) {
  if (!options.requirePhysicalHealth) {
    return;
  }
  final String platform = launch['platform']! as String;
  final String healthSource = launch['healthSource']! as String;
  final bool platformBacked =
      (platform == 'ios' && healthSource == 'healthkit') ||
      (platform == 'android' && healthSource == 'health_connect');
  if (!platformBacked) {
    throw const EvidenceVerifierFailure(
      'physical-health mode requires the platform Health source.',
    );
  }
  final Object? latestHealth = envelope['latestHealth'];
  final List<dynamic> journal = envelope['journal']! as List<dynamic>;
  if (latestHealth is! Map<String, dynamic> || journal.isEmpty) {
    throw const EvidenceVerifierFailure(
      'physical-health mode requires a recorded Health observation.',
    );
  }
}

void _writeSummary(
  StringSink output,
  Map<String, dynamic> envelope,
  Map<String, dynamic> launch,
) {
  final Map<String, dynamic> checksum =
      envelope['checksum']! as Map<String, dynamic>;
  final List<dynamic> journal = envelope['journal']! as List<dynamic>;
  output.writeln('Device validation evidence valid.');
  output.writeln('schemaVersion=${envelope['schemaVersion']}');
  output.writeln('sourceGitSha=${launch['sourceGitSha']}');
  output.writeln('appVersion=${launch['appVersion']}');
  output.writeln('buildNumber=${launch['buildNumber']}');
  output.writeln('platform=${launch['platform']}');
  output.writeln('healthSource=${launch['healthSource']}');
  output.writeln('journalEntries=${journal.length}');
  output.writeln('checksum=${checksum['value']}');
}
