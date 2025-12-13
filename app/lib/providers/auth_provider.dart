import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../api/auth_api.dart';
import '../models/user.dart' as model;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuthAPI _authApi = FirebaseAuthAPI();

  User? _firebaseUser;
  model.User? _appUser;

  User? get firebaseUser => _firebaseUser;
  model.User? get appUser => _appUser;
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _isLoading = true;
    _authApi.getUser().listen(
      (user) async {
        _firebaseUser = user;

        if (user != null) {
          try {
            _appUser = await _authApi.getUserInfo(user.uid);
          } catch (e) {
            print('Error fetching user info: $e');
            _appUser = null;
          }
        } else {
          _appUser = null;
        }
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        print('Auth stream error: $error');
        _isLoading = false;
        _firebaseUser = null;
        _appUser = null;
        notifyListeners();
      },
    );
  }

  Future<void> fetchUser() async {
    if (_firebaseUser != null) {
      _appUser = await _authApi.getUserInfo(_firebaseUser!.uid);
      notifyListeners();
    }
  }

  // sign in
  Future<String?> signIn(String email, String password) async {
    final result = await _authApi.signIn(email, password);
    if (result == null) {
      _firebaseUser = FirebaseAuth.instance.currentUser;
      if (_firebaseUser != null) {
        _appUser = await _authApi.getUserInfo(_firebaseUser!.uid);
        notifyListeners();
      }
    }
    return result;
  }

  // sign up
  Future<String?> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
  }) async {
    final result = await _authApi.signUp(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      username: username,
    );
    if (result == null) {
      _firebaseUser = FirebaseAuth.instance.currentUser;
      if (_firebaseUser != null) {
        _appUser = await _authApi.getUserInfo(_firebaseUser!.uid);
        notifyListeners();
      }
    }
    return result;
  }

  // sign out
  Future<void> signOut() async {
    await _authApi.signOut();
    _firebaseUser = null;
    _appUser = null;
    notifyListeners();
  }

  // update
  Future<String?> updateUserInfo(Map<String, dynamic> updatedData) async {
    if (_firebaseUser == null) return "No user signed in";
    final result = await _authApi.updateUserInfo(
      _firebaseUser!.uid,
      updatedData,
    );
    if (result == null) {
      _appUser = await _authApi.getUserInfo(_firebaseUser!.uid);
      notifyListeners();
    }
    return result;
  }

  //dDelete account
  Future<String?> deleteAccount() async {
    if (_firebaseUser == null) return "No user signed in";

    try {
      final userId = _firebaseUser!.uid;

      // call the delete function
      await _deleteUserData(userId);

      // Delete the Firebase Auth user
      await _firebaseUser!.delete();

      // Clear local state
      _firebaseUser = null;
      _appUser = null;
      notifyListeners();

      return null; // Success
    } catch (e) {
      return "Error deleting account: $e";
    }
  }

  Future<void> _deleteUserData(String userId) async {
    final batch = FirebaseFirestore.instance.batch();

    try {
      // get all courses for the user, and for each course, dekete all components and records associated with it
      final coursesSnapshot =
          await FirebaseFirestore.instance
              .collection('courses')
              .where('userId', isEqualTo: userId)
              .get();

      for (final courseDoc in coursesSnapshot.docs) {
        final courseId = courseDoc.id;

        final componentsSnapshot =
            await FirebaseFirestore.instance
                .collection('components')
                .where('courseId', isEqualTo: courseId)
                .get();

        for (final componentDoc in componentsSnapshot.docs) {
          final componentId = componentDoc.id;

          final recordsSnapshot =
              await FirebaseFirestore.instance
                  .collection('records')
                  .where('componentId', isEqualTo: componentId)
                  .get();

          // delete all records
          for (final recordDoc in recordsSnapshot.docs) {
            batch.delete(recordDoc.reference);
          }

          // delete the component
          batch.delete(componentDoc.reference);
        }

        // delete the course
        batch.delete(courseDoc.reference);
      }

      // delete the actual user document
      batch.delete(
        FirebaseFirestore.instance.collection('appusers').doc(userId),
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // sign out any existing google user
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return "Sign-in cancelled by user";
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      _firebaseUser = userCredential.user;

      if (_firebaseUser != null) {
        // create or update
        final userDoc =
            await FirebaseFirestore.instance
                .collection('appusers')
                .doc(_firebaseUser!.uid)
                .get();

        if (!userDoc.exists) {
          final newUser = model.User(
            userId: _firebaseUser!.uid,
            email: _firebaseUser!.email!,
            firstname: _firebaseUser!.displayName!.split(' ').first,
            lastname: _firebaseUser!.displayName!.split(' ').last,
            username: _firebaseUser!.email!.split('@').first,
            courses: const [],
          );

          await FirebaseFirestore.instance
              .collection('appusers')
              .doc(_firebaseUser!.uid)
              .set(newUser.toMap());

          _appUser = newUser;
        } else {
          _appUser = model.User.fromMap(userDoc.data()!);
        }

        // notify and return
        notifyListeners();
        return null;
      }

      return "Failed to sign in with Google";
    } catch (e) {
      return "Error: $e";
    }
  }
}
