class EquipmentResult {
  const EquipmentResult({
    required this.contentVersion,
    required this.slotId,
    required this.slotName,
    required this.slotDescription,
    required this.action,
    required this.changed,
    required this.version,
    required this.serverTime,
    this.equippedItem,
  });

  factory EquipmentResult.fromJson(Map<String, dynamic> json) {
    final String action = _readString(json, 'action');
    if (action != 'EQUIP' && action != 'UNEQUIP') {
      throw FormatException('Неизвестное equipment action: $action');
    }
    final Object? itemJson = json['equippedItem'];
    final EquippedItem? item = itemJson == null
        ? null
        : EquippedItem.fromJson(_asMap(itemJson, 'equippedItem'));
    if ((action == 'EQUIP') != (item != null)) {
      throw const FormatException(
        'Equipment action и equippedItem должны быть согласованы',
      );
    }
    return EquipmentResult(
      contentVersion: _readString(json, 'contentVersion'),
      slotId: _readString(json, 'slotId'),
      slotName: _readString(json, 'slotName'),
      slotDescription: _readString(json, 'slotDescription'),
      action: action,
      changed: _readBool(json, 'changed'),
      version: _readInt(json, 'version'),
      equippedItem: item,
      serverTime: _readString(json, 'serverTime'),
    );
  }

  final String contentVersion;
  final String slotId;
  final String slotName;
  final String slotDescription;
  final String action;
  final bool changed;
  final int version;
  final EquippedItem? equippedItem;
  final String serverTime;
}

class EquippedItem {
  const EquippedItem({
    required this.itemInstanceId,
    required this.itemId,
    required this.name,
    required this.description,
    required this.equippedAt,
  });

  factory EquippedItem.fromJson(Map<String, dynamic> json) {
    return EquippedItem(
      itemInstanceId: _readString(json, 'itemInstanceId'),
      itemId: _readString(json, 'itemId'),
      name: _readString(json, 'name'),
      description: _readString(json, 'description'),
      equippedAt: _readString(json, 'equippedAt'),
    );
  }

  final String itemInstanceId;
  final String itemId;
  final String name;
  final String description;
  final String equippedAt;
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

bool _readBool(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is bool) {
    return value;
  }
  throw FormatException('$field должен быть boolean');
}
