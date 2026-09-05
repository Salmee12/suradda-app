// Unit tests for the phone-number rules the subscribe flow depends on.
//
// The previous contents were the `flutter create` counter template, which failed
// against this app. Booting SurAddaApp in a test is not the useful thing to do
// here either — it needs the locator, secure storage and the audio session, all
// of which have no plugin implementation under `flutter test`. BdPhone is the
// piece with real branches, and it is pure Dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:suradda_app/core/utils/bd_phone.dart';

void main() {
  group('BdPhone.validate', () {
    test('accepts Robi and Cirkle numbers', () {
      expect(BdPhone.validate('01812345678'), isNull);
      expect(BdPhone.validate('01612345678'), isNull);
    });

    test('ignores separators the IME may insert', () {
      expect(BdPhone.validate('018 1234 5678'), isNull);
      expect(BdPhone.validate('018-1234-5678'), isNull);
    });

    test('asks for a number when the field is empty', () {
      expect(BdPhone.validate(''), contains('Enter your mobile number'));
    });

    test('reports a length problem as a fixable typo', () {
      // Distinct from the operator message on purpose: this one the user can
      // correct by typing, so it must not say the number will never work.
      expect(BdPhone.validate('0181234567'), contains('11-digit'));
      expect(BdPhone.validate('018123456789'), contains('11-digit'));
      expect(BdPhone.validate('01212345678'), contains('11-digit'));
    });

    test('rejects operators that cannot be billed through this app', () {
      expect(BdPhone.validate('01912345678'), contains('Robi (018)'));
      expect(BdPhone.validate('01712345678'), contains('Cirkle (016)'));
    });
  });

  group('BdPhone.operatorOf', () {
    test('derives the operator from the prefix', () {
      expect(BdPhone.operatorOf('01812345678'), BdOperator.robi);
      expect(BdPhone.operatorOf('01612345678'), BdOperator.cirkle);
    });

    test('returns null for anything else, so no chip is shown', () {
      expect(BdPhone.operatorOf('01712345678'), isNull);
      expect(BdPhone.operatorOf(''), isNull);
    });
  });

  group('BdPhone.toE164', () {
    test('converts the local form the field collects', () {
      expect(BdPhone.toE164('01812345678'), '+8801812345678');
    });

    test('is idempotent for numbers that already carry the country code', () {
      expect(BdPhone.toE164('8801812345678'), '+8801812345678');
      expect(BdPhone.toE164('+8801812345678'), '+8801812345678');
    });
  });
}
