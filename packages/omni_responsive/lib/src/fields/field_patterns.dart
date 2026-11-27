/// Regular expressions shared by the fields and `OmniValidators`. Compiled
/// once, because validators and formatters run on every keystroke.
/// Internal: not exported from the package.
library;

/// An ASCII uppercase letter.
final RegExp fieldReUpper = RegExp(r'[A-Z]');

/// An ASCII lowercase letter.
final RegExp fieldReLower = RegExp(r'[a-z]');

/// A digit.
final RegExp fieldReDigit = RegExp(r'\d');

/// A character that is not a letter, digit or space.
final RegExp fieldReSpecial = RegExp(r'[^a-zA-Z0-9\s]');

/// A non-digit.
final RegExp fieldReNonDigit = RegExp(r'\D');

/// Anything other than a digit or `+`.
final RegExp fieldReNonDialChar = RegExp(r'[^\d+]');

/// A string made only of digits.
final RegExp fieldReAllDigits = RegExp(r'^\d+$');

/// A whitespace character.
final RegExp fieldReSpace = RegExp(r'\s');

/// A character allowed in a username handle.
final RegExp fieldReHandleChar = RegExp(r'[a-zA-Z0-9._-]');
