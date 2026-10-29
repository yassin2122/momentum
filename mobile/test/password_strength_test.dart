import 'package:flutter_test/flutter_test.dart';
import 'package:grit/core/utils/password_strength.dart';
import 'package:grit/core/utils/validators.dart';

void main() {
  test('new passwords must meet the server rules', () {
    expect(Validators.newPassword('short1A'), isNotNull); // < 8 chars
    expect(Validators.newPassword('alllowercase1'), isNotNull); // no upper
    expect(Validators.newPassword('NoDigitsHere'), isNotNull);
    expect(Validators.newPassword('GoodPass1'), isNull);
  });

  test('sign-in only requires a password to be present', () {
    expect(Validators.password(''), isNotNull);
    expect(Validators.password('old6ch'), isNull);
  });

  test('strength levels', () {
    expect(PasswordStrength.evaluate(''), PasswordStrengthLevel.empty);
    expect(PasswordStrength.evaluate('abc'), PasswordStrengthLevel.weak);
    expect(PasswordStrength.evaluate('GoodPass1'), PasswordStrengthLevel.fair);
    expect(PasswordStrength.evaluate('GoodPass1!'), PasswordStrengthLevel.good);
    expect(
      PasswordStrength.evaluate('Very-Long-Passphrase-42'),
      PasswordStrengthLevel.strong,
    );
  });
}
