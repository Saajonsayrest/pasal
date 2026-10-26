import 'dart:math';

/// Letters and digits people can read aloud: no I, O, l, 0 or 1 (same set as the website).
const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

const passwordMinLength = 10;
const passwordMaxLength = 100;

/// A random 14 character password for a new staff login.
String generatePassword({Random? random}) {
  final rng = random ?? Random.secure();
  return List.generate(14, (_) => _alphabet[rng.nextInt(_alphabet.length)]).join();
}

/// True when the length is what the API accepts (10 to 100 characters).
bool passwordLengthOk(String password) => password.length >= passwordMinLength && password.length <= passwordMaxLength;
