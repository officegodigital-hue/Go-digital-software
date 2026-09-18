import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DownloadHistory {
  static const String _storageKey = 'go_digital_download_history';

  static Future<void> add({
    required String assetId,
    required String fileName,
    required String assetName,
    required String assetType,
    required String companyName,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_storageKey) ?? <String>[];

    final entry = <String, dynamic>{
      'assetId': assetId,
      'fileName': fileName,
      'assetName': assetName,
      'assetType': assetType,
      'companyName': companyName,
      'downloadedAt': DateTime.now().toIso8601String(),
    };

    raw.insert(0, jsonEncode(entry));

    // Keep the most recent 50 downloads.
    final limited = raw.take(50).toList();
    await preferences.setStringList(_storageKey, limited);
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_storageKey) ?? <String>[];
    final result = <Map<String, dynamic>>[];

    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) {
          result.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Ignore malformed history entries.
      }
    }

    return result;
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
