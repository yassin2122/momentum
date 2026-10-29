import '../constants/app_constants.dart';

/// How strong a new password is, for the live meter on sign-up / reset.
enum PasswordStrengthLevel { empty, weak, fair, good, strong }

abstract final class PasswordStrength {
  static final _lower = RegExp(r'[a-z]');
  static final _upper = RegExp(r'[A-Z]');
  static final _digit = RegExp(r'[0-9]');
  static final _symbol = RegExp(r'[^A-Za-z0-9]');

  /// Hard requirements — same as the server's `password_requirements =
  /// "lower_upper_letters_digits"` + `minimum_password_length = 8`.
  static List<String> missingRequirements(String value) => [
        if (value.length < AppConstants.minPasswordLength)
          '${AppConstants.minPasswordLength}+ characters',
        if (!_lower.hasMatch(value)) 'a lowercase letter',
        if (!_upper.hasMatch(value)) 'an uppercase letter',
        if (!_digit.hasMatch(value)) 'a number',
      ];

  static PasswordStrengthLevel evaluate(String value) {
    if (value.isEmpty) return PasswordStrengthLevel.empty;
    if (missingRequirements(value).isNotEmpty) return PasswordStrengthLevel.weak;
    var score = 0;
    if (value.length >= 12) score++;
    if (value.length >= 16) score++;
    if (_symbol.hasMatch(value)) score++;
    // Repeats like "aaaa" or "1111" make a password much easier to guess.
    if (RegExp(r'(.)\1{2,}').hasMatch(value)) score--;
    if (score <= 0) return PasswordStrengthLevel.fair;
    if (score == 1) return PasswordStrengthLevel.good;
    return PasswordStrengthLevel.strong;
  }
}
