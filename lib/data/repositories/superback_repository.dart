import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/superback_constants.dart';
import '../../core/utils/tenant_id_utils.dart';
import '../models/superback_config.dart';
import '../models/tenant_access.dart';
import '../models/tenant_control.dart';
import '../models/tenant_public.dart';
import '../models/tenant_view.dart';

class SuperbackRepository {
  final FirebaseFirestore firestore;

  const SuperbackRepository({required this.firestore});

  Future<bool> isAuthorizedSuperuser(String email) async {
    final String normalizedEmail = normalizeEmailKey(email);
    if (normalizedEmail.isEmpty) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection(SuperbackCollections.superbackConfig)
        .doc('main')
        .get();
    final SuperbackConfig config = SuperbackConfig.fromMap(snapshot.data());
    return config.adminEmails.contains(normalizedEmail);
  }

  Future<List<TenantView>> getTenants() async {
    final List<QuerySnapshot<Map<String, dynamic>>> snapshots = await Future.wait<QuerySnapshot<Map<String, dynamic>>>(
      <Future<QuerySnapshot<Map<String, dynamic>>>>[
        firestore
            .collection(SuperbackCollections.tenantsPublic)
            .orderBy('tenantName')
            .get(),
        firestore.collection(SuperbackCollections.tenantControl).get(),
      ],
    );

    final QuerySnapshot<Map<String, dynamic>> publicSnapshot = snapshots[0];
    final QuerySnapshot<Map<String, dynamic>> controlSnapshot = snapshots[1];

    final Map<String, TenantControl> controlsById = <String, TenantControl>{
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in controlSnapshot.docs)
        doc.id: TenantControl.fromMap(doc.id, doc.data()),
    };

    final List<TenantView> items = publicSnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final TenantPublic publicData = TenantPublic.fromMap(doc.id, doc.data());
          final TenantControl controlData = controlsById[doc.id] ?? TenantControl(
            id: doc.id,
            backendEnabled: false,
            updatedAt: publicData.updatedAt,
          );
          return TenantView(publicData: publicData, controlData: controlData);
        })
        .toList();

    items.sort((TenantView a, TenantView b) => a.tenantName.toLowerCase().compareTo(b.tenantName.toLowerCase()));
    return items;
  }

  Future<void> createTenant({
    required String tenantName,
    required String loginEmail,
    required bool frontendEnabled,
    required bool backendEnabled,
    required String subscriptionStatus,
    required String tenantStatus,
    required String actorEmail,
    String? explicitTenantId,
  }) async {
    final String normalizedEmail = normalizeEmailKey(loginEmail);
    final String tenantId = (explicitTenantId ?? '').trim().isNotEmpty
        ? explicitTenantId!.trim()
        : buildTenantId(tenantName: tenantName, loginEmail: normalizedEmail);

    final DocumentReference<Map<String, dynamic>> publicRef = firestore
        .collection(SuperbackCollections.tenantsPublic)
        .doc(tenantId);
    final DocumentReference<Map<String, dynamic>> controlRef = firestore
        .collection(SuperbackCollections.tenantControl)
        .doc(tenantId);
    final DocumentReference<Map<String, dynamic>> accessRef = firestore
        .collection(SuperbackCollections.tenantAccess)
        .doc(normalizedEmail);

    final List<DocumentSnapshot<Map<String, dynamic>>> existingDocs = await Future.wait<DocumentSnapshot<Map<String, dynamic>>>(
      <Future<DocumentSnapshot<Map<String, dynamic>>>>[
        publicRef.get(),
        accessRef.get(),
      ],
    );

    if (existingDocs[0].exists) {
      throw Exception('TenantId gia esistente: $tenantId');
    }
    if (existingDocs[1].exists) {
      throw Exception('Esiste gia un accesso con email: $normalizedEmail');
    }

    final DateTime now = DateTime.now();
    final TenantPublic publicData = TenantPublic(
      id: tenantId,
      tenantName: tenantName.trim(),
      loginEmail: normalizedEmail,
      frontendEnabled: frontendEnabled,
      subscriptionStatus: subscriptionStatus,
      tenantStatus: tenantStatus,
      createdAt: now,
      updatedAt: now,
    );
    final TenantControl controlData = TenantControl(
      id: tenantId,
      backendEnabled: backendEnabled,
      updatedAt: now,
    );
    final TenantAccess accessData = _buildTenantAccess(publicData);

    final WriteBatch batch = firestore.batch();
    batch.set(publicRef, publicData.toMap());
    batch.set(controlRef, controlData.toMap());
    batch.set(accessRef, accessData.toMap());
    batch.set(
      firestore.collection(SuperbackCollections.superbackAudit).doc(),
      _auditPayload(
        actorEmail: actorEmail,
        action: 'tenant_created',
        tenantId: tenantId,
        payload: <String, dynamic>{
          'tenantName': publicData.tenantName,
          'loginEmail': publicData.loginEmail,
          'frontendEnabled': publicData.frontendEnabled,
          'backendEnabled': controlData.backendEnabled,
          'subscriptionStatus': publicData.subscriptionStatus,
          'tenantStatus': publicData.tenantStatus,
        },
      ),
    );
    await batch.commit();
  }


  Future<void> updateTenant({
    required TenantView tenant,
    required String tenantName,
    required String loginEmail,
    required bool frontendEnabled,
    required bool backendEnabled,
    required String subscriptionStatus,
    required String tenantStatus,
    required String actorEmail,
  }) async {
    final String normalizedEmail = normalizeEmailKey(loginEmail);
    final DateTime now = DateTime.now();
    final TenantPublic nextPublic = tenant.publicData.copyWith(
      tenantName: tenantName.trim(),
      loginEmail: normalizedEmail,
      frontendEnabled: frontendEnabled,
      subscriptionStatus: subscriptionStatus,
      tenantStatus: tenantStatus,
      updatedAt: now,
    );
    final TenantControl nextControl = tenant.controlData.copyWith(
      backendEnabled: backendEnabled,
      updatedAt: now,
    );

    final DocumentReference<Map<String, dynamic>> newAccessRef = firestore
        .collection(SuperbackCollections.tenantAccess)
        .doc(normalizedEmail);
    final DocumentReference<Map<String, dynamic>> oldAccessRef = firestore
        .collection(SuperbackCollections.tenantAccess)
        .doc(tenant.loginEmail);

    if (normalizedEmail != tenant.loginEmail) {
      final DocumentSnapshot<Map<String, dynamic>> existing = await newAccessRef.get();
      if (existing.exists) {
        throw Exception('Esiste gia un accesso con email: $normalizedEmail');
      }
    }

    final WriteBatch batch = firestore.batch();
    batch.set(
      firestore.collection(SuperbackCollections.tenantsPublic).doc(tenant.id),
      nextPublic.toMap(),
    );
    batch.set(
      firestore.collection(SuperbackCollections.tenantControl).doc(tenant.id),
      nextControl.toMap(),
    );
    batch.set(newAccessRef, _buildTenantAccess(nextPublic).toMap());
    if (normalizedEmail != tenant.loginEmail) {
      batch.delete(oldAccessRef);
    }
    batch.set(
      firestore.collection(SuperbackCollections.superbackAudit).doc(),
      _auditPayload(
        actorEmail: actorEmail,
        action: 'tenant_updated',
        tenantId: tenant.id,
        payload: <String, dynamic>{
          'tenantName': nextPublic.tenantName,
          'loginEmail': nextPublic.loginEmail,
          'frontendEnabled': nextPublic.frontendEnabled,
          'backendEnabled': nextControl.backendEnabled,
          'subscriptionStatus': nextPublic.subscriptionStatus,
          'tenantStatus': nextPublic.tenantStatus,
        },
      ),
    );
    await batch.commit();
  }

  Future<void> setFrontendEnabled({
    required TenantView tenant,
    required bool value,
    required String actorEmail,
  }) async {
    final DateTime now = DateTime.now();
    final TenantPublic nextPublic = tenant.publicData.copyWith(
      frontendEnabled: value,
      updatedAt: now,
    );
    await _writePublicAndAccess(
      tenantId: tenant.id,
      publicData: nextPublic,
      actorEmail: actorEmail,
      action: 'tenant_frontend_enabled_changed',
      payload: <String, dynamic>{'frontendEnabled': value},
    );
  }

  Future<void> setTenantStatus({
    required TenantView tenant,
    required String value,
    required String actorEmail,
  }) async {
    final DateTime now = DateTime.now();
    final TenantPublic nextPublic = tenant.publicData.copyWith(
      tenantStatus: value,
      updatedAt: now,
    );
    await _writePublicAndAccess(
      tenantId: tenant.id,
      publicData: nextPublic,
      actorEmail: actorEmail,
      action: 'tenant_status_changed',
      payload: <String, dynamic>{'tenantStatus': value},
    );
  }

  Future<void> setSubscriptionStatus({
    required TenantView tenant,
    required String value,
    required String actorEmail,
  }) async {
    final DateTime now = DateTime.now();
    final TenantPublic nextPublic = tenant.publicData.copyWith(
      subscriptionStatus: value,
      updatedAt: now,
    );
    await _writePublicAndAccess(
      tenantId: tenant.id,
      publicData: nextPublic,
      actorEmail: actorEmail,
      action: 'tenant_subscription_changed',
      payload: <String, dynamic>{'subscriptionStatus': value},
    );
  }

  Future<void> setBackendEnabled({
    required TenantView tenant,
    required bool value,
    required String actorEmail,
  }) async {
    final TenantControl nextControl = tenant.controlData.copyWith(
      backendEnabled: value,
      updatedAt: DateTime.now(),
    );

    final WriteBatch batch = firestore.batch();
    batch.set(
      firestore.collection(SuperbackCollections.tenantControl).doc(tenant.id),
      nextControl.toMap(),
    );
    batch.set(
      firestore.collection(SuperbackCollections.superbackAudit).doc(),
      _auditPayload(
        actorEmail: actorEmail,
        action: 'tenant_backend_enabled_changed',
        tenantId: tenant.id,
        payload: <String, dynamic>{'backendEnabled': value},
      ),
    );
    await batch.commit();
  }

  Future<void> _writePublicAndAccess({
    required String tenantId,
    required TenantPublic publicData,
    required String actorEmail,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final WriteBatch batch = firestore.batch();
    batch.set(
      firestore.collection(SuperbackCollections.tenantsPublic).doc(tenantId),
      publicData.toMap(),
    );
    batch.set(
      firestore.collection(SuperbackCollections.tenantAccess).doc(publicData.loginEmail),
      _buildTenantAccess(publicData).toMap(),
    );
    batch.set(
      firestore.collection(SuperbackCollections.superbackAudit).doc(),
      _auditPayload(
        actorEmail: actorEmail,
        action: action,
        tenantId: tenantId,
        payload: payload,
      ),
    );
    await batch.commit();
  }

  TenantAccess _buildTenantAccess(TenantPublic publicData) {
    return TenantAccess(
      loginEmail: publicData.loginEmail,
      tenantId: publicData.id,
      frontendEnabled: publicData.frontendEnabled,
      tenantStatus: publicData.tenantStatus,
      subscriptionStatus: publicData.subscriptionStatus,
      updatedAt: publicData.updatedAt,
    );
  }

  Map<String, dynamic> _auditPayload({
    required String actorEmail,
    required String action,
    required String tenantId,
    required Map<String, dynamic> payload,
  }) {
    return <String, dynamic>{
      'actorEmail': normalizeEmailKey(actorEmail),
      'action': action,
      'tenantId': tenantId,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
