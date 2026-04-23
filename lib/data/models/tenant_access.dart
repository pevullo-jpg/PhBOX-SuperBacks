class TenantAccess {
  final String loginEmail;
  final String tenantId;
  final bool frontendEnabled;
  final String tenantStatus;
  final String subscriptionStatus;
  final DateTime updatedAt;

  const TenantAccess({
    required this.loginEmail,
    required this.tenantId,
    required this.frontendEnabled,
    required this.tenantStatus,
    required this.subscriptionStatus,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'loginEmail': loginEmail.trim().toLowerCase(),
      'tenantId': tenantId,
      'frontendEnabled': frontendEnabled,
      'tenantStatus': tenantStatus,
      'subscriptionStatus': subscriptionStatus,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
