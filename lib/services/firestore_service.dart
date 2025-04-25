import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ✅ Get Current User ID
  String? get userId => _auth.currentUser?.uid;

  // ✅ Ensure User Document Exists
  Future<void> _ensureUserDocumentExists() async {
    if (userId == null) throw Exception("User is not logged in");

    final userRef = _db.collection('users').doc(userId);
    final userDoc = await userRef.get();

    if (!userDoc.exists) {
      await userRef.set({
        'email': _auth.currentUser?.email ?? '',
        'displayName': '',
        'createdAt': FieldValue.serverTimestamp(),
      }); // ✅ Create document if it does not exist
    }
  }

  // ✅ Save User Data (Ensuring Document Exists)
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    if (userId == null) throw Exception("User is not logged in");

    await _ensureUserDocumentExists(); // ✅ Ensure document exists before saving
    await _db
        .collection('users')
        .doc(userId)
        .set(userData, SetOptions(merge: true));
  }

  // ✅ Update User Field (Ensuring Document Exists)
  Future<void> updateUserField(String field, dynamic value) async {
    if (userId == null) throw Exception("User is not logged in");

    await _ensureUserDocumentExists(); // ✅ Ensure document exists before updating
    await _db.collection('users').doc(userId).update({field: value});
  }

  // ✅ Get User Data
  Future<Map<String, dynamic>?> getUserData() async {
    if (userId == null) return null;

    final userDoc = await _db.collection('users').doc(userId).get();
    return userDoc.exists ? userDoc.data() as Map<String, dynamic> : null;
  }
}
