import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/gyms/presentation/widgets/gym_ui.dart';

void main() {
  group('Arabic digits (Postel\'s Law)', () {
    test('Arabic-Indic and Persian digits become ASCII', () {
      expect(gymNormalizeDigits('+٢٠ ١٠٠ ٥٥٥ ٢١٤٠'), '+20 100 555 2140');
      expect(gymNormalizeDigits('۱۲۳'), '123');
      expect(gymNormalizeDigits('٩٩٫٥'), '99.5');
      expect(gymNormalizeDigits('١٢٬٥٠٠'), '12,500');
    });

    test('other text is untouched', () {
      expect(gymNormalizeDigits('Iron Valley 24/7'), 'Iron Valley 24/7');
      expect(gymNormalizeDigits('صالة رياضية'), 'صالة رياضية');
    });

    test('the formatter keeps the cursor where it was', () {
      const formatter = GymDigitsFormatter();
      final out = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '٠١٠', selection: TextSelection.collapsed(offset: 3)),
      );
      expect(out.text, '010');
      expect(out.selection.baseOffset, 3);
    });
  });
}
