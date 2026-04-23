import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/superback_constants.dart';
import '../../../data/models/tenant_view.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/superback_repository.dart';
import '../../../theme/app_theme.dart';
import '../widgets/tenant_editor_dialog.dart';

class SuperbackDashboardPage extends StatefulWidget {
  final String actorEmail;

  const SuperbackDashboardPage({
    super.key,
    required this.actorEmail,
  });

  @override
  State<SuperbackDashboardPage> createState() => _SuperbackDashboardPageState();
}

class _SuperbackDashboardPageState extends State<SuperbackDashboardPage> {
  final SuperbackRepository _repository = SuperbackRepository(
    firestore: FirebaseFirestore.instance,
  );
  final AuthRepository _authRepository = AuthRepository(auth: FirebaseAuth.instance);
  final TextEditingController _searchController = TextEditingController();

  Future<List<TenantView>>? _future;
  final Set<String> _busyKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _repository.getTenants();
    });
  }

  Future<void> _runBusy(
    String key,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_busyKeys.contains(key)) {
      return;
    }
    setState(() {
      _busyKeys.add(key);
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      if (successMessage != null && successMessage.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage.trim())),
        );
      }
      _reload();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text('Operazione fallita: $e'),
        ),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyKeys.remove(key);
      });
    }
  }

  Future<void> _createTenant() async {
    final TenantEditorResult? result = await showDialog<TenantEditorResult>(
      context: context,
      builder: (_) => const TenantEditorDialog(
        isCreate: true,
        initialTenantId: '',
        initialTenantName: '',
        initialLoginEmail: '',
        initialFrontendEnabled: true,
        initialBackendEnabled: true,
        initialSubscriptionStatus: SubscriptionStatuses.trial,
        initialTenantStatus: TenantStatuses.active,
      ),
    );

    if (result == null) {
      return;
    }

    await _runBusy(
      'create_${result.tenantId}_${result.loginEmail}',
      () => _repository.createTenant(
        tenantName: result.tenantName,
        loginEmail: result.loginEmail,
        frontendEnabled: result.frontendEnabled,
        backendEnabled: result.backendEnabled,
        subscriptionStatus: result.subscriptionStatus,
        tenantStatus: result.tenantStatus,
        actorEmail: widget.actorEmail,
        explicitTenantId: result.tenantId.trim().isEmpty ? null : result.tenantId.trim(),
      ),
      successMessage: 'Farmacia creata.',
    );
  }

  Future<void> _editTenant(TenantView tenant) async {
    final TenantEditorResult? result = await showDialog<TenantEditorResult>(
      context: context,
      builder: (_) => TenantEditorDialog(
        isCreate: false,
        initialTenantId: tenant.id,
        initialTenantName: tenant.tenantName,
        initialLoginEmail: tenant.loginEmail,
        initialFrontendEnabled: tenant.frontendEnabled,
        initialBackendEnabled: tenant.backendEnabled,
        initialSubscriptionStatus: tenant.subscriptionStatus,
        initialTenantStatus: tenant.tenantStatus,
      ),
    );

    if (result == null) {
      return;
    }

    await _runBusy(
      'edit_${tenant.id}',
      () => _repository.updateTenant(
        tenant: tenant,
        tenantName: result.tenantName,
        loginEmail: result.loginEmail,
        frontendEnabled: result.frontendEnabled,
        backendEnabled: result.backendEnabled,
        subscriptionStatus: result.subscriptionStatus,
        tenantStatus: result.tenantStatus,
        actorEmail: widget.actorEmail,
      ),
      successMessage: 'Farmacia aggiornata.',
    );
  }

  List<TenantView> _filterTenants(List<TenantView> input) {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return input;
    }
    return input.where((TenantView tenant) {
      final String haystack = <String>[
        tenant.id,
        tenant.tenantName,
        tenant.loginEmail,
        tenant.subscriptionStatus,
        tenant.tenantStatus,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  String _formatDateTime(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String year = value.year.toString().padLeft(4, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Widget _buildSummaryCard({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(text),
    );
  }

  Color _subscriptionColor(String value) {
    switch (value) {
      case SubscriptionStatuses.active:
        return AppColors.green;
      case SubscriptionStatuses.suspended:
        return AppColors.amber;
      case SubscriptionStatuses.expired:
        return AppColors.red;
      case SubscriptionStatuses.trial:
      default:
        return AppColors.blue;
    }
  }

  Color _tenantStatusColor(String value) {
    switch (value) {
      case TenantStatuses.blocked:
        return AppColors.red;
      case TenantStatuses.active:
      default:
        return AppColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'SUPERBACK',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Superuser: ${widget.actorEmail}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _createTenant,
                    icon: const Icon(Icons.add),
                    label: const Text('Nuova farmacia'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Ricarica'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _authRepository.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Esci'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Cerca tenant, email, stato, abbonamento',
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<TenantView>>(
                  future: _future,
                  builder: (BuildContext context, AsyncSnapshot<List<TenantView>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Errore caricamento tenant: ${snapshot.error}'),
                      );
                    }

                    final List<TenantView> allTenants = snapshot.data ?? const <TenantView>[];
                    final List<TenantView> tenants = _filterTenants(allTenants);
                    final int frontendOn = allTenants.where((TenantView tenant) => tenant.frontendEnabled).length;
                    final int backendOn = allTenants.where((TenantView tenant) => tenant.backendEnabled).length;
                    final int blocked = allTenants.where((TenantView tenant) => tenant.tenantStatus == TenantStatuses.blocked).length;
                    final int activeSubscriptions = allTenants.where((TenantView tenant) => tenant.subscriptionStatus == SubscriptionStatuses.active).length;

                    final double width = MediaQuery.of(context).size.width;
                    final int summaryColumns = width > 1200 ? 4 : (width > 760 ? 2 : 1);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: summaryColumns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: summaryColumns == 1 ? 4.2 : 2.8,
                          children: <Widget>[
                            _buildSummaryCard(label: 'Tenant totali', value: allTenants.length, color: AppColors.yellow),
                            _buildSummaryCard(label: 'Frontend ON', value: frontendOn, color: AppColors.green),
                            _buildSummaryCard(label: 'Backend ON', value: backendOn, color: AppColors.blue),
                            _buildSummaryCard(label: 'Abbonamenti attivi', value: activeSubscriptions, color: AppColors.amber),
                          ],
                        ),
                        if (blocked > 0) ...<Widget>[
                          const SizedBox(height: 12),
                          Text('Tenant bloccati: $blocked', style: const TextStyle(color: Colors.white70)),
                        ],
                        const SizedBox(height: 20),
                        Expanded(
                          child: tenants.isEmpty
                              ? const Center(child: Text('Nessuna farmacia trovata.'))
                              : ListView.separated(
                                  itemCount: tenants.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (BuildContext context, int index) {
                                    final TenantView tenant = tenants[index];
                                    final bool isBusy = _busyKeys.any((String key) => key.contains(tenant.id));
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: <Widget>[
                                                      Text(
                                                        tenant.tenantName,
                                                        style: const TextStyle(
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(tenant.loginEmail),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'tenantId: ${tenant.id} • aggiornato: ${_formatDateTime(tenant.updatedAt)}',
                                                        style: const TextStyle(color: Colors.white60),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: <Widget>[
                                                    _buildBadge(
                                                      TenantStatuses.labelOf(tenant.tenantStatus),
                                                      _tenantStatusColor(tenant.tenantStatus),
                                                    ),
                                                    _buildBadge(
                                                      SubscriptionStatuses.labelOf(tenant.subscriptionStatus),
                                                      _subscriptionColor(tenant.subscriptionStatus),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Wrap(
                                              spacing: 24,
                                              runSpacing: 12,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: <Widget>[
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: <Widget>[
                                                    Switch.adaptive(
                                                      value: tenant.frontendEnabled,
                                                      onChanged: isBusy
                                                          ? null
                                                          : (bool value) => _runBusy(
                                                                'frontend_${tenant.id}',
                                                                () => _repository.setFrontendEnabled(
                                                                  tenant: tenant,
                                                                  value: value,
                                                                  actorEmail: widget.actorEmail,
                                                                ),
                                                                successMessage: 'Frontend aggiornato.',
                                                              ),
                                                    ),
                                                    const Text('Frontend'),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: <Widget>[
                                                    Switch.adaptive(
                                                      value: tenant.backendEnabled,
                                                      onChanged: isBusy
                                                          ? null
                                                          : (bool value) => _runBusy(
                                                                'backend_${tenant.id}',
                                                                () => _repository.setBackendEnabled(
                                                                  tenant: tenant,
                                                                  value: value,
                                                                  actorEmail: widget.actorEmail,
                                                                ),
                                                                successMessage: 'Backend aggiornato.',
                                                              ),
                                                    ),
                                                    const Text('Backend'),
                                                  ],
                                                ),
                                                SizedBox(
                                                  width: 180,
                                                  child: DropdownButtonFormField<String>(
                                                    value: tenant.subscriptionStatus,
                                                    decoration: const InputDecoration(labelText: 'Abbonamento'),
                                                    items: SubscriptionStatuses.values
                                                        .map(
                                                          (String value) => DropdownMenuItem<String>(
                                                            value: value,
                                                            child: Text(SubscriptionStatuses.labelOf(value)),
                                                          ),
                                                        )
                                                        .toList(),
                                                    onChanged: isBusy
                                                        ? null
                                                        : (String? value) {
                                                            if (value == null || value == tenant.subscriptionStatus) {
                                                              return;
                                                            }
                                                            _runBusy(
                                                              'subscription_${tenant.id}',
                                                              () => _repository.setSubscriptionStatus(
                                                                tenant: tenant,
                                                                value: value,
                                                                actorEmail: widget.actorEmail,
                                                              ),
                                                              successMessage: 'Abbonamento aggiornato.',
                                                            );
                                                          },
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 180,
                                                  child: DropdownButtonFormField<String>(
                                                    value: tenant.tenantStatus,
                                                    decoration: const InputDecoration(labelText: 'Stato tenant'),
                                                    items: TenantStatuses.values
                                                        .map(
                                                          (String value) => DropdownMenuItem<String>(
                                                            value: value,
                                                            child: Text(TenantStatuses.labelOf(value)),
                                                          ),
                                                        )
                                                        .toList(),
                                                    onChanged: isBusy
                                                        ? null
                                                        : (String? value) {
                                                            if (value == null || value == tenant.tenantStatus) {
                                                              return;
                                                            }
                                                            _runBusy(
                                                              'status_${tenant.id}',
                                                              () => _repository.setTenantStatus(
                                                                tenant: tenant,
                                                                value: value,
                                                                actorEmail: widget.actorEmail,
                                                              ),
                                                              successMessage: 'Stato tenant aggiornato.',
                                                            );
                                                          },
                                                  ),
                                                ),
                                                FilledButton.tonalIcon(
                                                  onPressed: isBusy ? null : () => _editTenant(tenant),
                                                  icon: const Icon(Icons.edit),
                                                  label: const Text('Modifica'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
