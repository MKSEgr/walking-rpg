import 'package:flutter_timezone/flutter_timezone.dart';

abstract interface class DeviceTimeZoneProvider {
  Future<String> getIdentifier();
}

class FlutterDeviceTimeZoneProvider implements DeviceTimeZoneProvider {
  const FlutterDeviceTimeZoneProvider();

  @override
  Future<String> getIdentifier() async {
    final TimezoneInfo timezone = await FlutterTimezone.getLocalTimezone();
    final String identifier = timezone.identifier.trim();
    if (identifier.isEmpty) {
      throw const DeviceTimeZoneException(
        'Операционная система не вернула IANA timezone',
      );
    }
    return identifier;
  }
}

class DeviceTimeZoneException implements Exception {
  const DeviceTimeZoneException(this.message);

  final String message;

  @override
  String toString() => message;
}
