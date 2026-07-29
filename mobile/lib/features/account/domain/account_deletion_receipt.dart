final class AccountDeletionReceipt {
  const AccountDeletionReceipt({
    required this.receiptId,
    required this.status,
    required this.requestedAt,
    required this.completedAt,
    required this.replayed,
  });

  factory AccountDeletionReceipt.fromJson(Map<String, dynamic> json) {
    final String receiptId = _requiredString(json, 'receiptId');
    final String status = _requiredString(json, 'status');
    if (status != 'COMPLETED') {
      throw FormatException('Неизвестный статус удаления аккаунта: $status');
    }
    final Object? replayed = json['replayed'];
    if (replayed is! bool) {
      throw const FormatException('replayed должен быть boolean');
    }
    return AccountDeletionReceipt(
      receiptId: receiptId,
      status: status,
      requestedAt: _requiredInstant(json, 'requestedAt'),
      completedAt: _requiredInstant(json, 'completedAt'),
      replayed: replayed,
    );
  }

  final String receiptId;
  final String status;
  final DateTime requestedAt;
  final DateTime completedAt;
  final bool replayed;

  static String _requiredString(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field обязателен');
    }
    return value.trim();
  }

  static DateTime _requiredInstant(Map<String, dynamic> json, String field) {
    final String value = _requiredString(json, field);
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$field должен быть ISO-8601 timestamp');
    }
    return parsed.toUtc();
  }
}
