/// The platform's own email check (signin.rs): one @, something before it,
/// a dot inside the domain, no spaces, at most 254 characters.
bool isValidEmail(String input) {
  final email = input.trim().toLowerCase();
  if (email.isEmpty || email.length > 254) return false;
  if (email.contains(RegExp(r'\s'))) return false;
  final parts = email.split('@');
  if (parts.length != 2) return false;
  final local = parts[0];
  final domain = parts[1];
  return local.isNotEmpty &&
      domain.contains('.') &&
      !domain.startsWith('.') &&
      !domain.endsWith('.');
}

/// "a•••@dominio.com": the first character, then dots, then the domain.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final first = String.fromCharCodes(email.runes.take(1));
  return '$first•••${email.substring(at)}';
}
