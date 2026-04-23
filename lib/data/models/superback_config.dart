import '../../core/utils/firestore_value_reader.dart';

class SuperbackConfig {
  final List<String> adminEmails;

  const SuperbackConfig({
    required this.adminEmails,
  });

  factory SuperbackConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const SuperbackConfig(adminEmails: <String>[]);
    }
    return SuperbackConfig(
      adminEmails: readStringList(map['adminEmails'])
          .map((String item) => item.trim().toLowerCase())
          .where((String item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    );
  }
}
