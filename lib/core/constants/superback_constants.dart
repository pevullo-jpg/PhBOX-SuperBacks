class SuperbackCollections {
  static const String superbackConfig = 'superback_config';
  static const String tenantsPublic = 'tenants_public';
  static const String tenantControl = 'tenant_control';
  static const String tenantAccess = 'tenant_access';
  static const String superbackAudit = 'superback_audit';
}

class SubscriptionStatuses {
  static const String trial = 'trial';
  static const String active = 'active';
  static const String suspended = 'suspended';
  static const String expired = 'expired';

  static const List<String> values = <String>[
    trial,
    active,
    suspended,
    expired,
  ];

  static String labelOf(String value) {
    switch (value) {
      case active:
        return 'Attivo';
      case suspended:
        return 'Sospeso';
      case expired:
        return 'Scaduto';
      case trial:
      default:
        return 'Trial';
    }
  }
}

class TenantStatuses {
  static const String active = 'active';
  static const String blocked = 'blocked';

  static const List<String> values = <String>[
    active,
    blocked,
  ];

  static String labelOf(String value) {
    switch (value) {
      case blocked:
        return 'Bloccato';
      case active:
      default:
        return 'Attivo';
    }
  }
}
