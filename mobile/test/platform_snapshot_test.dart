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
    expect(snapshot.userState.hasSuccessfulActivitySync, isTrue);
    expect(snapshot.userState.equippedCosmetics, const <String, String>{
      'PILOT': 'pilot-scarf',
    });
    expect(snapshot.userState.equippedCosmeticIds, const <String>{
      'pilot-scarf',
    });
  });

  test('maps independent server-owned cosmetic slots', () {
    final PlatformSnapshot snapshot = platformSnapshot(
      ownedCosmetics: const <String>['pilot-scarf', 'spark-halo'],
      activeCosmeticId: 'spark-halo',
      equippedCosmetics: const <String, String>{
        'PILOT': 'pilot-scarf',
        'PET': 'spark-halo',
      },
    );

    expect(snapshot.userState.equippedCosmetics, const <String, String>{
      'PILOT': 'pilot-scarf',
      'PET': 'spark-halo',
    });
    expect(snapshot.userState.equippedCosmeticIds, const <String>{
      'pilot-scarf',
      'spark-halo',
    });
  });

  test('falls back to the legacy cosmetic pointer when slots are absent', () {
    final Map<String, dynamic> json = platformSnapshotJson(
      ownedCosmetics: const <String>['pilot-scarf', 'spark-halo'],
      activeCosmeticId: 'spark-halo',
    );
    final Map<String, dynamic> userState = Map<String, dynamic>.from(
      json['userState']! as Map<String, dynamic>,
    )..remove('equippedCosmetics');
    json['userState'] = userState;

    final PlatformSnapshot snapshot = PlatformSnapshot.fromJson(json);

    expect(snapshot.userState.equippedCosmetics, isEmpty);
    expect(snapshot.userState.equippedCosmeticIds, const <String>{
      'spark-halo',
    });
  });

  test('keeps an explicit empty cosmetic slot mapping authoritative', () {
    final PlatformSnapshot snapshot = platformSnapshot(
      equippedCosmetics: const <String, String>{},
    );

    expect(snapshot.userState.activeCosmeticId, 'pilot-scarf');
    expect(snapshot.userState.equippedCosmeticIds, isEmpty);
  });

  test('rejects equipped cosmetics that are not owned', () {
    expect(
      () => platformSnapshot(
        equippedCosmetics: const <String, String>{'PET': 'spark-halo'},
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('falls back to lifetime steps for an older platform response', () {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> userState = Map<String, dynamic>.from(
      json['userState']! as Map<String, dynamic>,
    )..remove('hasSuccessfulActivitySync');
    json['userState'] = userState;

    final PlatformSnapshot snapshot = PlatformSnapshot.fromJson(json);

    expect(snapshot.userState.hasSuccessfulActivitySync, isTrue);
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
