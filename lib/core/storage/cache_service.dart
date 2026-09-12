import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class _CacheEntry {
  final dynamic data;
  final DateTime expiresAt;

  _CacheEntry(this.data, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Centralized caching service adhering strictly to Section 8.4 and Section 9.3.
///
/// PERMITTED TO CACHE:
/// - Catalogue & Categories
/// - Static Content
/// - Feature configuration & remote config
///
/// STRICTLY FORBIDDEN TO CACHE UNENCRYPTED (Section 9.3):
/// - Medical diagnoses, lab reports, prescriptions
/// - Private dietitian notes, sensitive health metrics
/// - Payment credentials, raw auth secrets
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, _CacheEntry> _memoryCache = {};

  /// Set in-memory cache with Time-To-Live
  void setMemory(String key, dynamic data, {Duration ttl = const Duration(minutes: 15)}) {
    _memoryCache[key] = _CacheEntry(data, DateTime.now().add(ttl));
  }

  /// Get in-memory cache if not expired
  T? getMemory<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _memoryCache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  /// Persistent cache for non-sensitive data (e.g. catalogue, categories)
  Future<void> setPersistent(String key, dynamic data, {Duration ttl = const Duration(hours: 4)}) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = {
      'data': data,
      'expiresAt': DateTime.now().add(ttl).toIso8601String(),
    };
    await prefs.setString('cache_$key', jsonEncode(entry));
  }

  /// Get persistent cache for non-sensitive data
  Future<dynamic> getPersistent(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_$key');
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(decoded['expiresAt'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        await prefs.remove('cache_$key');
        return null;
      }
      return decoded['data'];
    } catch (_) {
      await prefs.remove('cache_$key');
      return null;
    }
  }

  /// Invalidate specific key
  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cache_$key');
  }

  /// Invalidate all caches (e.g. upon user sign-out - Section 21.4)
  Future<void> clearAll() async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
