import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart' as model;

class FirebaseAuthAPI {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Stream<User?> getUser() => auth.authStateChanges();

  // sign in user with email and password
  Future<String?> signIn(String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.code; 
    }
  }

  // sign up user and create Firestore user document
  Future<String?> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
  }) async {
    try {
      UserCredential newUser = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      String uid = newUser.user!.uid;

      // create user model instance
      final appUser = model.User(
        userId: uid,
        username: username,
        firstname: firstName,
        lastname: lastName,
        email: email,
        courses: const [],
      );

      // save and sign in the user
      await db.collection("appusers").doc(uid).set(appUser.toMap());
      await auth.signInWithEmailAndPassword(email: email, password: password);

      return null;
    } on FirebaseAuthException catch (e) {
      return "Failed with error '${e.code}: ${e.message}'";
    }
  }

  // sign out
  Future<void> signOut() async {
    await auth.signOut();
  }

  // fetch user info 
  Future<model.User?> getUserInfo(String uid) async {
    try {
      DocumentSnapshot doc = await db.collection("appusers").doc(uid).get();
      if (doc.exists) {
        return model.User.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // update 
  Future<String?> updateUserInfo(
    String uid,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      await db.collection("appusers").doc(uid).update(updatedData);
      return null; // Success
    } catch (e) {
      return "Error updating user details: $e";
    }
  }
}
