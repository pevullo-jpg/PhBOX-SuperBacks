import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'data/repositories/superback_repository.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/unauthorized_page.dart';
import 'features/dashboard/pages/superback_dashboard_page.dart';
import 'theme/app_theme.dart';

class SuperbackApp extends StatelessWidget {
  const SuperbackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SUPERBACK',
      theme: AppTheme.darkTheme,
      home: const _AppGate(),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final User? user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }
        return _AuthorizationGate(user: user);
      },
    );
  }
}

class _AuthorizationGate extends StatelessWidget {
  final User user;

  const _AuthorizationGate({required this.user});

  @override
  Widget build(BuildContext context) {
    final SuperbackRepository repository = SuperbackRepository(
      firestore: FirebaseFirestore.instance,
    );
    final String email = user.email?.trim().toLowerCase() ?? '';

    return FutureBuilder<bool>(
      future: repository.isAuthorizedSuperuser(email),
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Errore verifica superuser: ${snapshot.error}'),
              ),
            ),
          );
        }
        if (snapshot.data != true) {
          return UnauthorizedPage(email: email);
        }
        return SuperbackDashboardPage(actorEmail: email);
      },
    );
  }
}
