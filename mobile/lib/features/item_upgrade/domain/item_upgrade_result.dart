class ItemUpgradeResult {
  const ItemUpgradeResult({
    required this.contentVersion,
    required this.upgradeId,
    required this.upgradeVersion,
    required this.upgradeName,
    required this.consumedIngredients,
    required this.upgradedItem,
    required this.serverTime,
  });

  factory ItemUpgradeResult.fromJson(Map<String, dynamic> json) {
    final Object? rawIngredients = json['consumedIngredients'];
    if (rawIngredients is! List<dynamic> || rawIngredients.isEmpty) {
      throw const FormatException(
        'consumedIngredients должен быть непустым JSON-массивом',
      );
    }
    return ItemUpgradeResult(
      contentVersion: _readString(json, 'contentVersion'),
      upgradeId: _readString(json, 'upgradeId'),
      upgradeVersion: _readString(json, 'upgradeVersion'),
      upgradeName: _readString(json, 'upgradeName'),
      consumedIngredients: rawIngredients
          .map(
            (Object? value) => ItemUpgradeIngredientResult.fromJson(
              _asMap(value, 'consumedIngredients[]'),
            ),
          )
          .toList(growable: false),
      upgradedItem: UpgradedUniqueItem.fromJson(
        _asMap(json['upgradedItem'], 'upgradedItem'),
      ),
      serverTime: _readString(json, 'serverTime'),
    );
  }

  final String contentVersion;
  final String upgradeId;
  final String upgradeVersion;
  final String upgradeName;
  final List<ItemUpgradeIngredientResult> consumedIngredients;
  final UpgradedUniqueItem upgradedItem;
  final String serverTime;
}

class ItemUpgradeIngredientResult {
  const ItemUpgradeIngredientResult({
    required this.itemId,
    required this.name,
    required this.quantityConsumed,
    required this.quantityAfter,
    required this.version,
  });

  factory ItemUpgradeIngredientResult.fromJson(Map<String, dynamic> json) {
    return ItemUpgradeIngredientResult(
      itemId: _readString(json, 'itemId'),
      name: _readString(json, 'name'),
      quantityConsumed: _readInt(json, 'quantityConsumed'),
      quantityAfter: _readInt(json, 'quantityAfter'),
      version: _readInt(json, 'version'),
    );
  }

  final String itemId;
  final String name;
  final int quantityConsumed;
  final int quantityAfter;
  final int version;
}

class UpgradedUniqueItem {
  const UpgradedUniqueItem({
    required this.itemInstanceId,
    required this.itemId,
    required this.name,
    required this.description,
    required this.previousLevel,
    required this.upgradeLevel,
    required this.rarity,
    required this.upgradedAt,
  });

  factory UpgradedUniqueItem.fromJson(Map<String, dynamic> json) {
    return UpgradedUniqueItem(
      itemInstanceId: _readString(json, 'itemInstanceId'),
      itemId: _readString(json, 'itemId'),
      name: _readString(json, 'name'),
      description: _readString(json, 'description'),
      previousLevel: _readInt(json, 'previousLevel'),
      upgradeLevel: _readInt(json, 'upgradeLevel'),
      rarity: _readString(json, 'rarity'),
      upgradedAt: _readString(json, 'upgradedAt'),
    );
  }

  final String itemInstanceId;
  final String itemId;
  final String name;
  final String description;
  final int previousLevel;
  final int upgradeLevel;
  final String rarity;
  final String upgradedAt;
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('$field должен быть JSON-объектом');
  }
  return value.map<String, dynamic>((Object? key, Object? item) {
    if (key is! String) {
      throw FormatException('Ключи $field должны быть строками');
    }
    return MapEntry<String, dynamic>(key, item);
  });
}

String _readString(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field должен быть непустой строкой');
  }
  return value;
}

int _readInt(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is int) {
    return value;
  }
  if (value is num && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$field должен быть целым числом');
}
