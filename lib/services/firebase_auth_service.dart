import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Sign in with Email & Password
  Future<User?> signInWithEmail(String email, String password) async {
    final UserCredential userCredential = await _auth
        .signInWithEmailAndPassword(email: email, password: password);
    return userCredential.user;
  }

  // ✅ Register with Email & Password
  Future<User?> registerWithEmail(String email, String password) async {
    final UserCredential userCredential = await _auth
        .createUserWithEmailAndPassword(email: email, password: password);
    return userCredential.user;
  }

  // ✅ Sign Out
  Future<void> signOut() async {
    await _auth.signOut(); // Only Firebase sign-out now
  }

  // ✅ Check Authentication State
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
