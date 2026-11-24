// lib/shared/utils/dashboard_image_validation.dart
import 'dart:typed_data';

enum DashboardImageValidationIssue {
  tooSmall,
  tooLarge,
  unsupported,
}

class DashboardImageValidationResult {
  const DashboardImageValidationResult({
    required this.isValid,
    this.issue,
  });

  final bool isValid;
  final DashboardImageValidationIssue? issue;
}

class DashboardImageValidation {
  static DashboardImageValidationResult check(
    Uint8List bytes, {
    bool requireMinimumSize = true,
  }) {
    // 1 MB = 1,000,000 bytes, 10 MB = 10,000,000 bytes
    const int minBytes = 50 * 1024;
    const int maxBytes = 10 * 1024 * 1024;

    if (requireMinimumSize && bytes.length < minBytes) {
      return const DashboardImageValidationResult(
        isValid: false,
        issue: DashboardImageValidationIssue.tooSmall,
      );
    }

    if (bytes.length > maxBytes) {
      return const DashboardImageValidationResult(
        isValid: false,
        issue: DashboardImageValidationIssue.tooLarge,
      );
    }

    // Verify common image signatures (PNG, JPEG, WebP)
    bool isSupported = false;
    if (bytes.length > 12) {
      // PNG signature: 89 50 4E 47 0D 0A 1A 0A
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        isSupported = true;
      }
      // JPEG signature: FF D8 FF
      else if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        isSupported = true;
      }
      // WebP signature: RIFF ... WEBP
      else if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        isSupported = true;
      }
    }

    if (!isSupported) {
      return const DashboardImageValidationResult(
        isValid: false,
        issue: DashboardImageValidationIssue.unsupported,
      );
    }

    return const DashboardImageValidationResult(isValid: true);
  }
}