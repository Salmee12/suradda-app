/// Bangladeshi mobile number handling for the BDApps subscription flow.
///
/// Only Robi (018) and Cirkle (016) can be billed through this app's BDApps
/// registration, so those are the only prefixes accepted. The operator is derived
/// from the prefix rather than asked for: the prefix already determines it, so a
/// picker could only ever disagree with the number and produce a confusing
/// "Robi numbers should start with 018" for someone who typed a valid number.
///
/// Cirkle is 016, the operator BDApps' own documentation still calls Airtel.
enum BdOperator {
  robi('Robi', '018'),
  cirkle('Cirkle', '016');

  const BdOperator(this.label, this.prefix);
  final String label;
  final String prefix;
}

class BdPhone {
  BdPhone._();

  /// 11 digits, `01` then a valid operator digit. Matches the shape
  /// `send_otp.php` validates against, so the app rejects locally what the server
  /// would reject anyway.
  static final RegExp _shape = RegExp(r'^01[3-9]\d{8}$');

  static BdOperator? operatorOf(String raw) {
    final digits = digitsOnly(raw);
    for (final op in BdOperator.values) {
      if (digits.startsWith(op.prefix)) return op;
    }
    return null;
  }

  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// Null when the number is usable, otherwise the reason to show the user.
  ///
  /// The two failures are kept distinct on purpose. "Not 11 digits" is a typo the
  /// user can fix; "not Robi or Cirkle" is a number that will never work here,
  /// and telling that user to check their digits would send them in circles.
  static String? validate(String raw) {
    final digits = digitsOnly(raw);
    if (digits.isEmpty) return 'Enter your mobile number.';
    if (!_shape.hasMatch(digits)) {
      return 'Enter an 11-digit number starting with 01, e.g. 01XXXXXXXXX.';
    }
    if (operatorOf(digits) == null) {
      return 'Only Robi (018) and Cirkle (016) numbers can subscribe.';
    }
    return null;
  }

  /// `01712345678` -> `+8801712345678`, the form the backend stores.
  static String toE164(String raw) {
    final digits = digitsOnly(raw);
    if (digits.startsWith('880')) return '+$digits';
    if (digits.startsWith('0')) return '+880${digits.substring(1)}';
    return '+880$digits';
  }
}
