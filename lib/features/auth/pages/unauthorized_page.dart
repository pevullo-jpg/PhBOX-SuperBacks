import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../data/repositories/auth_repository.dart';

class UnauthorizedPage extends StatelessWidget {
  final String email;

  const UnauthorizedPage({
    super.key,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final AuthRepository authRepository = AuthRepository(auth: FirebaseAuth.instance);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Accesso negato',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'L\'utente $email non e registrato in superback_config/main.adminEmails.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bootstrap richiesto: crea il documento Firestore superback_config/main con il campo adminEmails contenente la tua email.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => authRepository.signOut(),
                    child: const Text('Esci'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
