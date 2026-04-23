String normalizeEmailKey(String value) {
  return value.trim().toLowerCase();
}

String buildTenantId({
  required String tenantName,
  required String loginEmail,
}) {
  final String base = tenantName.trim().isNotEmpty
      ? tenantName.trim().toLowerCase()
      : loginEmail.split('@').first.trim().toLowerCase();
  final String normalized = base
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (normalized.isEmpty) {
    return 'tenant';
  }
  return normalized;
}
