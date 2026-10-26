import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/settings/data/password.dart';

void main() {
  test('a generated password is 14 characters from the readable set', () {
    final password = generatePassword(random: Random(42));
    expect(password, hasLength(14));
    expect(password, matches(RegExp(r'^[A-HJ-NP-Za-km-z2-9]{14}$')));
  });

  test('the same random source gives the same password', () {
    expect(generatePassword(random: Random(1)), generatePassword(random: Random(1)));
  });

  test('two secure passwords are different', () {
    expect(generatePassword(), isNot(generatePassword()));
  });

  test('the length rule is 10 to 100 characters', () {
    expect(passwordLengthOk(''), isFalse);
    expect(passwordLengthOk('a' * 9), isFalse);
    expect(passwordLengthOk('a' * 10), isTrue);
    expect(passwordLengthOk('a' * 100), isTrue);
    expect(passwordLengthOk('a' * 101), isFalse);
  });
}
