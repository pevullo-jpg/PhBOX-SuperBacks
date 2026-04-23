import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth auth;

  const AuthRepository({required this.auth});

  Stream<User?> authStateChanges() => auth.authStateChanges();

  Future<void> signIn({
    required String email,
    required String password,
  }) {
    return auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => auth.signOut();
}
