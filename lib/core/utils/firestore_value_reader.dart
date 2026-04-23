String readString(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? fallback : normalized;
}

String? readNullableString(dynamic value) {
  final String normalized = readString(value);
  return normalized.isEmpty ? null : normalized;
}

bool readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  final String normalized = value?.toString().trim().toLowerCase() ?? '';
  if (normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'si' || normalized == 'sì') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

DateTime? readDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  try {
    final dynamic converted = (value as dynamic).toDate();
    if (converted is DateTime) {
      return converted;
    }
  } catch (_) {}
  try {
    final dynamic seconds = (value as dynamic).seconds;
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
  } catch (_) {}
  return null;
}

List<String> readStringList(dynamic value) {
  if (value is List) {
    return value
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }
  final String raw = value?.toString() ?? '';
  if (raw.trim().isEmpty) {
    return const <String>[];
  }
  return raw
      .split(RegExp(r'[\n,;|]+'))
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList();
}
