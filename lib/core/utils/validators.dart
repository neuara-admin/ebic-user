/// Comprehensive input validators for EBIC mobile application.
/// Used for immediate client-side validation across auth and future forms.
class Validators {
  Validators._();

  /// Validates an Indian (or international) mobile phone number.
  /// Returns null if valid, or an error message string if invalid.
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your mobile phone number.';
    }

    // Clean formatting characters
    final cleaned = value.replaceAll(RegExp(r'[\s\-().]'), '').trim();

    // Check if Indian format with country code (+91XXXXXXXXXX or 91XXXXXXXXXX)
    if (cleaned.startsWith('+91')) {
      final numberPart = cleaned.substring(3);
      if (numberPart.length != 10) {
        return 'Phone number must have 10 digits after +91.';
      }
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(numberPart)) {
        return 'Please enter a valid Indian mobile number starting with 6, 7, 8, or 9.';
      }
      return null;
    }

    if (cleaned.startsWith('91') && cleaned.length == 12) {
      final numberPart = cleaned.substring(2);
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(numberPart)) {
        return 'Please enter a valid Indian mobile number starting with 6, 7, 8, or 9.';
      }
      return null;
    }

    // Check 10-digit Indian mobile number
    if (RegExp(r'^\d{10}$').hasMatch(cleaned)) {
      if (!RegExp(r'^[6-9]').hasMatch(cleaned)) {
        return 'Mobile numbers in India must start with 6, 7, 8, or 9.';
      }
      return null;
    }

    // Check international E.164 (+ and 10-15 digits)
    if (cleaned.startsWith('+') && RegExp(r'^\+[1-9]\d{9,14}$').hasMatch(cleaned)) {
      return null;
    }

    if (cleaned.length < 10) {
      return 'Phone number is too short. Please enter a 10-digit mobile number.';
    }

    if (cleaned.length > 10 && !cleaned.startsWith('+')) {
      return 'Phone number is too long. Please enter a 10-digit mobile number.';
    }

    return 'Please enter a valid mobile number (e.g. 9876543210).';
  }

  /// Normalizes a raw phone string into standard E.164 format (e.g. +919876543210).
  static String normalizePhone(String rawPhone) {
    final cleaned = rawPhone.replaceAll(RegExp(r'[\s\-().]'), '').trim();
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      return '+91${cleaned.substring(1)}';
    }
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      return '+$cleaned';
    }
    if (cleaned.length == 10) {
      return '+91$cleaned';
    }
    return '+91$cleaned';
  }

  /// Validates a 6-digit OTP verification code.
  static String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the 6-digit verification code.';
    }
    final cleaned = value.trim();
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Verification code must contain only numbers.';
    }
    if (cleaned.length != 6) {
      return 'Please enter the complete 6-digit code (${cleaned.length}/6 entered).';
    }
    return null;
  }

  /// Validates an email address.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address.';
    }
    final cleaned = value.trim();
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
    );
    if (!emailRegex.hasMatch(cleaned)) {
      return 'Please enter a valid email address (e.g. name@domain.com).';
    }
    return null;
  }

  /// Validates a password field.
  static String? validatePassword(String? value, {int minLength = 6, bool requireComplexity = false}) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password.';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters long.';
    }
    if (requireComplexity || minLength >= 8) {
      if (!RegExp(r'[a-zA-Z]').hasMatch(value) || !RegExp(r'[0-9]').hasMatch(value)) {
        return 'Password must contain both letters and numbers.';
      }
    }
    return null;
  }

  /// Validates a required general text field.
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  /// Validates an optional referral or promo code.
  static String? validateReferralCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional
    }
    final cleaned = value.trim();
    if (cleaned.length < 3 || cleaned.length > 20) {
      return 'Referral code must be between 3 and 20 characters.';
    }
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(cleaned)) {
      return 'Referral code can only contain letters, numbers, hyphens and underscores.';
    }
    return null;
  }
}
