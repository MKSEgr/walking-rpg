abstract final class CharacterCosmeticIds {
  static const String pilotScarf = 'pilot-scarf';
  static const String sparkHalo = 'spark-halo';

  static Set<String> fromLegacyActive(String? cosmeticId) {
    return cosmeticId == null ? const <String>{} : <String>{cosmeticId};
  }
}
