class CraftingResult {
  const CraftingResult({
    required this.contentVersion,
    required this.recipeId,
    required this.recipeVersion,
    required this.recipeName,
    required this.consumedIngredients,
    required this.craftedItem,
    required this.serverTime,
  });

  factory CraftingResult.fromJson(Map<String, dynamic> json) {
    final Object? rawIngredients = json['consumedIngredients'];
    if (rawIngredients is! List<dynamic> || rawIngredients.isEmpty) {
      throw const FormatException(
        'consumedIngredients должен быть непустым JSON-массивом',
      );
    }
    return CraftingResult(
      contentVersion: _readString(json, 'contentVersion'),
      recipeId: _readString(json, 'recipeId'),
      recipeVersion: _readString(json, 'recipeVersion'),
      recipeName: _readString(json, 'recipeName'),
      consumedIngredients: rawIngredients
          .map(
            (Object? value) => CraftingIngredientResult.fromJson(
              _asMap(value, 'consumedIngredients[]'),
            ),
          )
          .toList(growable: false),
      craftedItem: CraftedUniqueItem.fromJson(
        _asMap(json['craftedItem'], 'craftedItem'),
      ),
      serverTime: _readString(json, 'serverTime'),
    );
  }

  final String contentVersion;
  final String recipeId;
  final String recipeVersion;
  final String recipeName;
  final List<CraftingIngredientResult> consumedIngredients;
  final CraftedUniqueItem craftedItem;
  final String serverTime;
}

class CraftingIngredientResult {
  const CraftingIngredientResult({
    required this.itemId,
    required this.name,
    required this.quantityConsumed,
    required this.quantityAfter,
    required this.version,
  });

  factory CraftingIngredientResult.fromJson(Map<String, dynamic> json) {
    return CraftingIngredientResult(
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

class CraftedUniqueItem {
  const CraftedUniqueItem({
    required this.itemInstanceId,
    required this.itemId,
    required this.name,
    required this.description,
    required this.version,
    required this.craftedAt,
  });

  factory CraftedUniqueItem.fromJson(Map<String, dynamic> json) {
    return CraftedUniqueItem(
      itemInstanceId: _readString(json, 'itemInstanceId'),
      itemId: _readString(json, 'itemId'),
      name: _readString(json, 'name'),
      description: _readString(json, 'description'),
      version: _readInt(json, 'version'),
      craftedAt: _readString(json, 'craftedAt'),
    );
  }

  final String itemInstanceId;
  final String itemId;
  final String name;
  final String description;
  final int version;
  final String craftedAt;
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
