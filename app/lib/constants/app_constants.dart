/// Application string constants for localization and consistency
class AppStrings {
  // Auth screens
  static const String welcomeBack = 'Welcome back!';
  static const String pleaseLoginToContinue = 'Please login to continue';
  static const String createNewAccount = 'Create new\naccount';
  static const String logIn = 'Log In';
  static const String signUp = 'Sign Up';
  
  // Form labels
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String firstName = 'First Name';
  static const String lastName = 'Last Name';
  static const String username = 'Username';
  
  // Validation messages
  static const String emailRequired = 'Email is required';
  static const String emailInvalid = 'Please enter a valid email address';
  static const String passwordRequired = 'Password is required';
  static const String confirmPasswordRequired = 'Confirm password is required';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  static const String firstNameRequired = 'First name is required';
  static const String lastNameRequired = 'Last name is required';
  static const String usernameRequired = 'Username is required';
  
  // Error messages
  static const String noUserSignedIn = 'No user signed in';
  static const String signInCancelled = 'Sign-in cancelled by user';
  static const String googleSignInFailed = 'Failed to sign in with Google';
}

/// Firebase collection name constants
class Collections {
  static const String users = 'appusers';
  static const String courses = 'courses';
  static const String components = 'components';
  static const String records = 'records';
}

/// Firebase error message mapping for user-friendly messages
class FirebaseErrorMessages {
  static String mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        return 'Authentication error: $code';
    }
  }
}

/// Form validators
class Validators {
  static final RegExp _emailRegex = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.emailRequired;
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return AppStrings.emailInvalid;
    }
    return null;
  }

  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.passwordRequired;
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.confirmPasswordRequired;
    }
    if (value != password) {
      return AppStrings.passwordsDoNotMatch;
    }
    return null;
  }
}
