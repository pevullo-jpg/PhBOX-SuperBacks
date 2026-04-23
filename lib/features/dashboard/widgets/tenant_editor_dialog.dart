import 'package:flutter/material.dart';

import '../../../core/constants/superback_constants.dart';

class TenantEditorResult {
  final String tenantId;
  final String tenantName;
  final String loginEmail;
  final bool frontendEnabled;
  final bool backendEnabled;
  final String subscriptionStatus;
  final String tenantStatus;

  const TenantEditorResult({
    required this.tenantId,
    required this.tenantName,
    required this.loginEmail,
    required this.frontendEnabled,
    required this.backendEnabled,
    required this.subscriptionStatus,
    required this.tenantStatus,
  });
}

class TenantEditorDialog extends StatefulWidget {
  final bool isCreate;
  final String initialTenantId;
  final String initialTenantName;
  final String initialLoginEmail;
  final bool initialFrontendEnabled;
  final bool initialBackendEnabled;
  final String initialSubscriptionStatus;
  final String initialTenantStatus;

  const TenantEditorDialog({
    super.key,
    required this.isCreate,
    required this.initialTenantId,
    required this.initialTenantName,
    required this.initialLoginEmail,
    required this.initialFrontendEnabled,
    required this.initialBackendEnabled,
    required this.initialSubscriptionStatus,
    required this.initialTenantStatus,
  });

  @override
  State<TenantEditorDialog> createState() => _TenantEditorDialogState();
}

class _TenantEditorDialogState extends State<TenantEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _tenantIdController;
  late final TextEditingController _tenantNameController;
  late final TextEditingController _loginEmailController;
  late bool _frontendEnabled;
  late bool _backendEnabled;
  late String _subscriptionStatus;
  late String _tenantStatus;

  @override
  void initState() {
    super.initState();
    _tenantIdController = TextEditingController(text: widget.initialTenantId);
    _tenantNameController = TextEditingController(text: widget.initialTenantName);
    _loginEmailController = TextEditingController(text: widget.initialLoginEmail);
    _frontendEnabled = widget.initialFrontendEnabled;
    _backendEnabled = widget.initialBackendEnabled;
    _subscriptionStatus = widget.initialSubscriptionStatus;
    _tenantStatus = widget.initialTenantStatus;
  }

  @override
  void dispose() {
    _tenantIdController.dispose();
    _tenantNameController.dispose();
    _loginEmailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      TenantEditorResult(
        tenantId: _tenantIdController.text.trim(),
        tenantName: _tenantNameController.text.trim(),
        loginEmail: _loginEmailController.text.trim().toLowerCase(),
        frontendEnabled: _frontendEnabled,
        backendEnabled: _backendEnabled,
        subscriptionStatus: _subscriptionStatus,
        tenantStatus: _tenantStatus,
      ),
    );
  }

  String? _validateEmail(String? value) {
    final String email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'Email obbligatoria.';
    }
    final RegExp regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(email)) {
      return 'Email non valida.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      title: Text(widget.isCreate ? 'Nuova farmacia' : 'Modifica farmacia'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _tenantIdController,
                  readOnly: !widget.isCreate,
                  decoration: const InputDecoration(
                    labelText: 'TenantId',
                    helperText: 'Lascia vuoto per generazione automatica.',
                  ),
                  validator: (String? value) {
                    final String tenantId = (value ?? '').trim();
                    if (tenantId.isEmpty) {
                      return null;
                    }
                    final RegExp regex = RegExp(r'^[a-zA-Z0-9_-]+$');
                    if (!regex.hasMatch(tenantId)) {
                      return 'TenantId valido: lettere, numeri, _ e -.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tenantNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome farmacia',
                  ),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Nome farmacia obbligatorio.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _loginEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email login farmacia',
                    helperText: 'L\'account Firebase Auth va creato manualmente con la stessa email.',
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  value: _frontendEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      _frontendEnabled = value;
                    });
                  },
                  title: const Text('Frontend abilitato'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile.adaptive(
                  value: _backendEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      _backendEnabled = value;
                    });
                  },
                  title: const Text('Backend abilitato'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _subscriptionStatus,
                  items: SubscriptionStatuses.values
                      .map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(SubscriptionStatuses.labelOf(value)),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Abbonamento',
                  ),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _subscriptionStatus = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _tenantStatus,
                  items: TenantStatuses.values
                      .map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(TenantStatuses.labelOf(value)),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Stato tenant',
                  ),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _tenantStatus = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isCreate ? 'Crea' : 'Salva'),
        ),
      ],
    );
  }
}
