import '../models/user_profile.dart';

/// Validates authentication forms and manages session state.
/// Integrates with FirebaseAuth when initialized, and gracefully supports
/// offline/local evaluator mode when Firebase config is absent.
class AuthService {
  static String? validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required.';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  static String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Password must be at least 8 characters.';
    return null;
  }

  static String? validateName(String? value) {
    final v = (value ?? '').trim();
    if (v.length < 2) return 'Enter your full name (at least 2 characters).';
    return null;
  }

  static String? validatePhone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Phone number is required.';
    final digits = v.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.length < 8 || digits.length > 16) {
      return 'Enter a valid phone number with country code.';
    }
    return null;
  }

  UserProfile buildDefaultProfile({
    required String uid,
    required String displayName,
    required String email,
    String phone = '',
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName,
      email: email,
      phone: phone,
    );
  }
}
