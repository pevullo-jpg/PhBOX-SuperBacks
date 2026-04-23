import '../../core/constants/superback_constants.dart';
import '../../core/utils/firestore_value_reader.dart';

class TenantPublic {
  final String id;
  final String tenantName;
  final String loginEmail;
  final bool frontendEnabled;
  final String subscriptionStatus;
  final String tenantStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TenantPublic({
    required this.id,
    required this.tenantName,
    required this.loginEmail,
    required this.frontendEnabled,
    required this.subscriptionStatus,
    required this.tenantStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TenantPublic.fromMap(String id, Map<String, dynamic>? map) {
    final DateTime now = DateTime.now();
    return TenantPublic(
      id: id,
      tenantName: readString(map?['tenantName'], fallback: id),
      loginEmail: readString(map?['loginEmail']).toLowerCase(),
      frontendEnabled: readBool(map?['frontendEnabled'], fallback: false),
      subscriptionStatus: _normalizeSubscriptionStatus(
        readString(map?['subscriptionStatus'], fallback: SubscriptionStatuses.trial),
      ),
      tenantStatus: _normalizeTenantStatus(
        readString(map?['tenantStatus'], fallback: TenantStatuses.active),
      ),
      createdAt: readDateTime(map?['createdAt']) ?? now,
      updatedAt: readDateTime(map?['updatedAt']) ?? now,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tenantId': id,
      'tenantName': tenantName,
      'loginEmail': loginEmail.trim().toLowerCase(),
      'frontendEnabled': frontendEnabled,
      'subscriptionStatus': _normalizeSubscriptionStatus(subscriptionStatus),
      'tenantStatus': _normalizeTenantStatus(tenantStatus),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  TenantPublic copyWith({
    String? tenantName,
    String? loginEmail,
    bool? frontendEnabled,
    String? subscriptionStatus,
    String? tenantStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TenantPublic(
      id: id,
      tenantName: tenantName ?? this.tenantName,
      loginEmail: loginEmail ?? this.loginEmail,
      frontendEnabled: frontendEnabled ?? this.frontendEnabled,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      tenantStatus: tenantStatus ?? this.tenantStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _normalizeSubscriptionStatus(String value) {
    return SubscriptionStatuses.values.contains(value)
        ? value
        : SubscriptionStatuses.trial;
  }

  static String _normalizeTenantStatus(String value) {
    return TenantStatuses.values.contains(value)
        ? value
        : TenantStatuses.active;
  }
}
