import '../constants/app_constants.dart';

/// Shared form-field validators. Kept UI-agnostic (pure functions returning
/// an error string or null) so they can be reused by any TextFormField's
/// `validator` across features, not just Auth.
abstract final class Validators {
  static final RegExp _emailRegex =
      RegExp(r'^[\w\.\-+]+@[\w\-]+\.[a-zA-Z]{2,}$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(
    String Function() originalPassword,
  ) {
    return (value) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != originalPassword()) {
        return 'Passwords do not match';
      }
      return null;
    };
  }
}
