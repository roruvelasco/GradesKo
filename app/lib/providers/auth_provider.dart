import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../api/auth_api.dart';
import '../models/user.dart' as model;
import '../constants/app_constants.dart';

/// Authentication state management provider
/// Handles user authentication state and operations
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
            if (kDebugMode) {
              debugPrint('Error fetching user info: $e');
            }
            _appUser = null;
          }
        } else {
          _appUser = null;
        }
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('Auth stream error: $error');
        }
        _isLoading = false;
        _firebaseUser = null;
        _appUser = null;
        notifyListeners();
      },
    );
  }

  /// Fetch user info from Firestore
  Future<void> fetchUser() async {
    if (_firebaseUser != null) {
      _appUser = await _authApi.getUserInfo(_firebaseUser!.uid);
      notifyListeners();
    }
  }

  /// Sign in with email and password
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

  /// Sign up with email and password
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

  /// Sign out the current user
  Future<void> signOut() async {
    await _authApi.signOut();
    _firebaseUser = null;
    _appUser = null;
    notifyListeners();
  }

  /// Update user info in Firestore
  Future<String?> updateUserInfo(Map<String, dynamic> updatedData) async {
    if (_firebaseUser == null) return AppStrings.noUserSignedIn;
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

  /// Delete user account and all associated data
  Future<String?> deleteAccount() async {
    if (_firebaseUser == null) return AppStrings.noUserSignedIn;

    try {
      final userId = _firebaseUser!.uid;

      // Delete all user data from Firestore (delegated to API layer)
      await _authApi.deleteUserData(userId);

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

  /// Sign in with Google account
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Sign out any existing google user to allow account selection
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return AppStrings.signInCancelled;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      _firebaseUser = userCredential.user;

      if (_firebaseUser != null) {
        // Check if user document exists, create if not
        final userDoc = await FirebaseFirestore.instance
            .collection(Collections.users)
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
              .collection(Collections.users)
              .doc(_firebaseUser!.uid)
              .set(newUser.toMap());

          _appUser = newUser;
        } else {
          _appUser = model.User.fromMap(userDoc.data()!);
        }

        notifyListeners();
        return null;
      }

      return AppStrings.googleSignInFailed;
    } catch (e) {
      return "Error: $e";
    }
  }
}
