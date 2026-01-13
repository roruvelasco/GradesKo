import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart' as model;
import '../constants/app_constants.dart';

/// Firebase Authentication API layer
/// Handles all Firebase Auth and user document operations
class FirebaseAuthAPI {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  /// Returns a stream of auth state changes
  Stream<User?> getUser() => auth.authStateChanges();

  /// Sign in user with email and password
  /// Returns null on success, user-friendly error message on failure
  Future<String?> signIn(String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return FirebaseErrorMessages.mapAuthError(e.code);
    }
  }

  /// Sign up user and create Firestore user document
  /// Returns null on success, user-friendly error message on failure
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

      // Create user model instance
      final appUser = model.User(
        userId: uid,
        username: username,
        firstname: firstName,
        lastname: lastName,
        email: email,
        courses: const [],
      );

      // Save user document to Firestore
      await db.collection(Collections.users).doc(uid).set(appUser.toMap());
      
      // Sign in the newly created user
      await auth.signInWithEmailAndPassword(email: email, password: password);

      return null;
    } on FirebaseAuthException catch (e) {
      return FirebaseErrorMessages.mapAuthError(e.code);
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await auth.signOut();
  }

  /// Fetch user info from Firestore
  Future<model.User?> getUserInfo(String uid) async {
    try {
      DocumentSnapshot doc = await db.collection(Collections.users).doc(uid).get();
      if (doc.exists) {
        return model.User.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update user info in Firestore
  /// Returns null on success, error message on failure
  Future<String?> updateUserInfo(
    String uid,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      await db.collection(Collections.users).doc(uid).update(updatedData);
      return null; // Success
    } catch (e) {
      return "Error updating user details: $e";
    }
  }

  /// Delete all user data from Firestore (courses, components, records)
  /// Used when deleting user account
  Future<void> deleteUserData(String userId) async {
    final batch = db.batch();

    try {
      // Get all courses for the user
      final coursesSnapshot = await db
          .collection(Collections.courses)
          .where('userId', isEqualTo: userId)
          .get();

      for (final courseDoc in coursesSnapshot.docs) {
        final courseId = courseDoc.id;

        // Get and delete all components for this course
        final componentsSnapshot = await db
            .collection(Collections.components)
            .where('courseId', isEqualTo: courseId)
            .get();

        for (final componentDoc in componentsSnapshot.docs) {
          final componentId = componentDoc.id;

          // Get and delete all records for this component
          final recordsSnapshot = await db
              .collection(Collections.records)
              .where('componentId', isEqualTo: componentId)
              .get();

          // Delete all records
          for (final recordDoc in recordsSnapshot.docs) {
            batch.delete(recordDoc.reference);
          }

          // Delete the component
          batch.delete(componentDoc.reference);
        }

        // Delete the course
        batch.delete(courseDoc.reference);
      }

      // Delete the user document
      batch.delete(db.collection(Collections.users).doc(userId));

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}
