import 'tenant_control.dart';
import 'tenant_public.dart';

class TenantView {
  final TenantPublic publicData;
  final TenantControl controlData;

  const TenantView({
    required this.publicData,
    required this.controlData,
  });

  String get id => publicData.id;
  String get tenantName => publicData.tenantName;
  String get loginEmail => publicData.loginEmail;
  bool get frontendEnabled => publicData.frontendEnabled;
  bool get backendEnabled => controlData.backendEnabled;
  String get subscriptionStatus => publicData.subscriptionStatus;
  String get tenantStatus => publicData.tenantStatus;
  DateTime get createdAt => publicData.createdAt;
  DateTime get updatedAt => publicData.updatedAt.isAfter(controlData.updatedAt)
      ? publicData.updatedAt
      : controlData.updatedAt;
}
