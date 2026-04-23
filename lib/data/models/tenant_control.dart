import '../../core/utils/firestore_value_reader.dart';

class TenantControl {
  final String id;
  final bool backendEnabled;
  final DateTime updatedAt;

  const TenantControl({
    required this.id,
    required this.backendEnabled,
    required this.updatedAt,
  });

  factory TenantControl.fromMap(String id, Map<String, dynamic>? map) {
    return TenantControl(
      id: id,
      backendEnabled: readBool(map?['backendEnabled'], fallback: false),
      updatedAt: readDateTime(map?['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': id,
      'backendEnabled': backendEnabled,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  TenantControl copyWith({
    bool? backendEnabled,
    DateTime? updatedAt,
  }) {
    return TenantControl(
      id: id,
      backendEnabled: backendEnabled ?? this.backendEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
