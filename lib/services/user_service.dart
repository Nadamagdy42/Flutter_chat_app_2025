import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔹 Store user profile with username + email
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String username,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'username': username.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 🔹 Username lookup table for uniqueness
    await _firestore.collection('usernames').doc(username).set({
      'uid': uid,
    });
  }

  /// 🔹 Fetch user by UID → for chat list UI
  Future<UserModel?> getUserByUid(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, uid: uid);
  }

  /// 🔹 Search by username (starts with)
  Stream<List<UserModel>> searchUsers(String query, String currentUid) {
    return _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
        .where('username', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) => doc.id != currentUid)
            .map((doc) => UserModel.fromMap(doc.data(), uid: doc.id))
            .toList());
  }

  /// 🔹 Get all users except self (fallback)
  Stream<List<UserModel>> getAllUsersExceptMe(String currentUid) {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) => doc.id != currentUid)
            .map((doc) => UserModel.fromMap(doc.data(), uid: doc.id))
            .toList());
  }
}
