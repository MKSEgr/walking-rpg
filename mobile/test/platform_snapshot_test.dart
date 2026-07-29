import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';

import 'support/platform_fixture.dart';

void main() {
  test('maps authoritative platform snapshot and computed progress', () {
    final PlatformSnapshot snapshot = platformSnapshot();

    expect(snapshot.contentVersion, 'chapter-1-v1');
    expect(snapshot.content.chapterNodes, 18);
    expect(snapshot.userState.pets, hasLength(3));
    expect(snapshot.activePet.petId, 'spark-v1');
    expect(snapshot.activePet.canEvolve, isTrue);
    expect(snapshot.weeklyRouteRemaining, 60);
    expect(snapshot.weeklyRouteProgressValue, 0.4);
    expect(snapshot.onboardingProgressValue, closeTo(1 / 6, 0.0001));
    expect(snapshot.claimableSeasonLevel, 2);
    expect(snapshot.remoteConfig.sandboxPaymentsEnabled, isTrue);
  });

  test('caps claimable season level by content definition', () {
    final PlatformSnapshot snapshot = platformSnapshot(seasonXp: 5000);

    expect(snapshot.claimableSeasonLevel, 10);
  });

  test('rejects content version mismatch', () {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> content = Map<String, dynamic>.from(
      json['content']! as Map<String, dynamic>,
    );
    content['contentVersion'] = 'chapter-other';
    json['content'] = content;

    expect(
      () => PlatformSnapshot.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects inconsistent active pet flags', () {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> userState = Map<String, dynamic>.from(
      json['userState']! as Map<String, dynamic>,
    );
    final List<dynamic> pets = List<dynamic>.from(
      userState['pets']! as List<dynamic>,
    );
    final Map<String, dynamic> first = Map<String, dynamic>.from(
      pets.first as Map<String, dynamic>,
    );
    first['active'] = false;
    pets[0] = first;
    userState['pets'] = pets;
    json['userState'] = userState;

    expect(
      () => PlatformSnapshot.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });
}
