import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../data/datasources/health_remote_datasource.dart';

// Samsung Health is deliberately NOT a separate enum value: on Android,
// Samsung Health (like every other wearable app) writes into Health
// Connect rather than exposing its own sync API, so "connecting" it would
// be the exact same OS permission grant as Health Connect. Offering it as
// a second connectable card let a user end up with two "connected"
// providers after only really granting permission once — see
// double-envelope-bug memory / 2026-09-26 fix.
enum HealthProviderEnum {
  appleHealth,
  healthConnect,
}

extension HealthProviderExtension on HealthProviderEnum {
  String get apiKey {
    switch (this) {
      case HealthProviderEnum.appleHealth:
        return 'APPLE_HEALTH';
      case HealthProviderEnum.healthConnect:
        return 'HEALTH_CONNECT';
    }
  }

  String get displayName {
    switch (this) {
      case HealthProviderEnum.appleHealth:
        return 'Apple Health';
      case HealthProviderEnum.healthConnect:
        return 'Health Connect';
    }
  }

  String get description {
    switch (this) {
      case HealthProviderEnum.appleHealth:
        return 'Sync steps, sleep, heart rate, and workouts from Apple Health & Apple Watch.';
      case HealthProviderEnum.healthConnect:
        return 'Sync steps, active calories, sleep, and vitals via Android Health Connect — including data written by Samsung Health and other wearable apps.';
    }
  }

  bool get isAvailableOnCurrentPlatform {
    switch (this) {
      case HealthProviderEnum.appleHealth:
        return defaultTargetPlatform == TargetPlatform.iOS;
      case HealthProviderEnum.healthConnect:
        return defaultTargetPlatform == TargetPlatform.android;
    }
  }

  /// The device health types EBIC reads for this provider. Distance uses a
  /// different native type per platform; everything else is shared.
  List<HealthDataType> get _dataTypes {
    final isIOS = this == HealthProviderEnum.appleHealth;
    return [
      HealthDataType.STEPS,
      isIOS ? HealthDataType.DISTANCE_WALKING_RUNNING : HealthDataType.DISTANCE_DELTA,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.WEIGHT,
      HealthDataType.HEIGHT,
      HealthDataType.WATER,
      HealthDataType.BLOOD_OXYGEN,
      if (isIOS) HealthDataType.EXERCISE_TIME,
    ];
  }
}

/// Maps a raw [HealthDataPoint] read from HealthKit / Health Connect into
/// the canonical `{metric, value, unit}` shape EBIC's backend expects
/// (see ebic-backend `NormalizationService` and `IHealthProvider.supportedMetrics`).
/// Returns null for point types EBIC doesn't track.
class _CanonicalRecord {
  final String metric;
  final String unit;
  final double value;
  const _CanonicalRecord(this.metric, this.unit, this.value);
}

_CanonicalRecord? _canonicalize(HealthDataType type, HealthDataUnit unit, num raw) {
  switch (type) {
    case HealthDataType.STEPS:
      return _CanonicalRecord('STEPS', 'count', raw.toDouble());
    case HealthDataType.DISTANCE_WALKING_RUNNING:
    case HealthDataType.DISTANCE_DELTA:
      return _CanonicalRecord('DISTANCE', 'meters', _toMeters(unit, raw));
    case HealthDataType.ACTIVE_ENERGY_BURNED:
      return _CanonicalRecord('ACTIVE_CALORIES', 'kcal', _toKcal(unit, raw));
    case HealthDataType.SLEEP_ASLEEP:
    case HealthDataType.SLEEP_SESSION:
      return _CanonicalRecord('SLEEP_DURATION', 'minutes', _toMinutes(unit, raw));
    case HealthDataType.HEART_RATE:
      return _CanonicalRecord('HEART_RATE', 'bpm', raw.toDouble());
    case HealthDataType.RESTING_HEART_RATE:
      return _CanonicalRecord('RESTING_HEART_RATE', 'bpm', raw.toDouble());
    case HealthDataType.WEIGHT:
      return _CanonicalRecord('WEIGHT', 'kg', _toKg(unit, raw));
    case HealthDataType.HEIGHT:
      return _CanonicalRecord('HEIGHT', 'cm', _toCm(unit, raw));
    case HealthDataType.WATER:
      return _CanonicalRecord('WATER_INTAKE', 'ml', _toMl(unit, raw));
    case HealthDataType.EXERCISE_TIME:
      return _CanonicalRecord('EXERCISE_MINUTES', 'minutes', _toMinutes(unit, raw));
    case HealthDataType.BLOOD_OXYGEN:
      // HealthKit reports SpO2 as a 0.0–1.0 fraction; Health Connect as 0-100.
      final pct = raw.toDouble();
      return _CanonicalRecord('BLOOD_OXYGEN', '%', pct <= 1 ? pct * 100 : pct);
    default:
      return null;
  }
}

double _toMeters(HealthDataUnit u, num v) {
  switch (u) {
    case HealthDataUnit.CENTIMETER:
      return v / 100;
    case HealthDataUnit.MILE:
      return v * 1609.344;
    case HealthDataUnit.FOOT:
      return v * 0.3048;
    case HealthDataUnit.YARD:
      return v * 0.9144;
    case HealthDataUnit.INCH:
      return v * 0.0254;
    default:
      return v.toDouble(); // METER
  }
}

double _toKcal(HealthDataUnit u, num v) {
  switch (u) {
    case HealthDataUnit.JOULE:
      return v / 4184;
    case HealthDataUnit.SMALL_CALORIE:
      return v / 1000;
    default:
      return v.toDouble(); // KILOCALORIE / LARGE_CALORIE
  }
}

double _toMinutes(HealthDataUnit u, num v) {
  switch (u) {
    case HealthDataUnit.SECOND:
      return v / 60;
    case HealthDataUnit.MILLISECOND:
      return v / 60000;
    case HealthDataUnit.HOUR:
      return v * 60;
    case HealthDataUnit.DAY:
      return v * 1440;
    default:
      return v.toDouble(); // MINUTE
  }
}

double _toKg(HealthDataUnit u, num v) {
  switch (u) {
    case HealthDataUnit.GRAM:
      return v / 1000;
    case HealthDataUnit.POUND:
      return v * 0.45359237;
    case HealthDataUnit.OUNCE:
      return v * 0.0283495;
    case HealthDataUnit.STONE:
      return v * 6.35029;
    default:
      return v.toDouble(); // KILOGRAM
  }
}

double _toCm(HealthDataUnit u, num v) {
  switch (u) {
    case HealthDataUnit.METER:
      return v * 100;
    case HealthDataUnit.INCH:
      return v * 2.54;
    case HealthDataUnit.FOOT:
      return v * 30.48;
    default:
      return v.toDouble(); // CENTIMETER
  }
}

double _toMl(HealthDataUnit u, num v) {
  switch (u) {
    case HealthDataUnit.LITER:
      return v * 1000;
    case HealthDataUnit.FLUID_OUNCE_US:
      return v * 29.5735;
    case HealthDataUnit.CUP_US:
      return v * 236.588;
    default:
      return v.toDouble(); // MILLILITER
  }
}

class HealthProviderManager extends ChangeNotifier {
  static final HealthProviderManager _instance = HealthProviderManager._internal();
  factory HealthProviderManager() => _instance;
  HealthProviderManager._internal();

  final HealthRemoteDataSource _dataSource = HealthRemoteDataSource();
  final Health _health = Health();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _syncStatusMessage;
  String? get syncStatusMessage => _syncStatusMessage;

  /// Set when [connect] or [syncNow] fails, so the UI can show *why* rather
  /// than silently doing nothing.
  String? _lastError;
  String? get lastError => _lastError;

  List<dynamic> _connections = [];
  List<dynamic> get connections => _connections;

  Map<String, dynamic>? _overview;
  Map<String, dynamic>? get overview => _overview;

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        _dataSource.getConnectedSources(),
        _dataSource.getHealthOverview(),
      ]);
      _connections = results[0] as List<dynamic>;
      _overview = results[1] as Map<String, dynamic>?;
      notifyListeners();
    } catch (e) {
      debugPrint('[HealthProviderManager] Refresh error: $e');
    }
  }

  bool isConnected(HealthProviderEnum provider) {
    return _connections.any(
      (c) =>
          c['provider'] == provider.apiKey &&
          (c['status'] == 'CONNECTED' || c['status'] == 'SYNCED'),
    );
  }

  String? getLastSync(HealthProviderEnum provider) {
    final match = _connections.firstWhere(
      (c) => c['provider'] == provider.apiKey,
      orElse: () => null,
    );
    if (match != null && match['lastSyncAt'] != null) {
      final dt = DateTime.tryParse(match['lastSyncAt'].toString())?.toLocal();
      if (dt != null) {
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final minute = dt.minute.toString().padLeft(2, '0');
        return '$hour:$minute $ampm';
      }
    }
    return null;
  }

  /// Requests OS-level permission to read [provider]'s health data, and only
  /// once that is actually granted, registers the connection with the
  /// backend and pulls the first batch of real device data.
  Future<bool> connect(HealthProviderEnum provider) async {
    _isSyncing = true;
    _lastError = null;
    _syncStatusMessage = 'Connecting to ${provider.displayName}...';
    notifyListeners();

    try {
      await _ensureConfigured();

      final isAndroidProvider = provider != HealthProviderEnum.appleHealth;
      if (isAndroidProvider && !(await _health.isHealthConnectAvailable())) {
        _lastError =
            'Health Connect is not installed or needs an update. Opening the Play Store — please install it and try again.';
        await _health.installHealthConnect();
        return false;
      }

      final types = provider._dataTypes;
      final granted = await _health.requestAuthorization(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ),
      );

      if (!granted) {
        _lastError =
            'Permission was not granted for ${provider.displayName}. EBIC only reads the data listed above — nothing is synced without your consent.';
        return false;
      }

      final res = await _dataSource.connectHealthSource({
        'provider': provider.apiKey,
        'sourceName': provider.displayName,
        'appVersion': '1.0.0',
        'os': Platform.isIOS ? 'iOS' : 'Android',
      });

      if (res == null) {
        _lastError = 'Could not register the connection with EBIC. Please try again.';
        return false;
      }

      // Initial sync pulls real data from the device right away so the
      // connection isn't left showing "Connected" with nothing behind it.
      final synced = await syncNow(provider, isInitial: true);
      await refresh();
      return synced;
    } catch (e) {
      debugPrint('[HealthProviderManager] Connect error: $e');
      _lastError = 'Something went wrong connecting to ${provider.displayName}.';
      return false;
    } finally {
      _isSyncing = false;
      _syncStatusMessage = null;
      notifyListeners();
    }
  }

  Future<bool> disconnect(HealthProviderEnum provider) async {
    final match = _connections.firstWhere(
      (c) => c['provider'] == provider.apiKey,
      orElse: () => null,
    );

    if (match != null && match['id'] != null) {
      final ok = await _dataSource.disconnectHealthSource(match['id'].toString());
      if (ok) {
        await refresh();
        return true;
      }
    }
    return false;
  }

  /// Reads real data from HealthKit / Health Connect for the window since
  /// the last sync (or the last 7 days on first connect) and uploads exactly
  /// what was found — never a fabricated payload.
  Future<bool> syncNow(HealthProviderEnum provider, {bool isInitial = false}) async {
    _isSyncing = true;
    _lastError = null;
    _syncStatusMessage = 'Reading health data from ${provider.displayName}...';
    notifyListeners();

    try {
      await _ensureConfigured();

      final types = provider._dataTypes;
      final hasPermission = await _health.hasPermissions(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ),
      );
      if (hasPermission != true) {
        _lastError = 'EBIC no longer has permission to read ${provider.displayName}. Reconnect to grant access again.';
        return false;
      }

      final now = DateTime.now();
      final lookback = isInitial ? const Duration(days: 7) : const Duration(hours: 36);
      final points = await _health.getHealthDataFromTypes(
        types: types,
        startTime: now.subtract(lookback),
        endTime: now,
      );

      final records = <Map<String, dynamic>>[];
      for (final p in points) {
        final value = p.value;
        if (value is! NumericHealthValue) continue;
        final canon = _canonicalize(p.type, p.unit, value.numericValue);
        if (canon == null) continue;
        records.add({
          'metric': canon.metric,
          'value': canon.value,
          'unit': canon.unit,
          'startTime': p.dateFrom.toIso8601String(),
          'endTime': p.dateTo.toIso8601String(),
          'sourceRecordId': p.uuid,
          'metadata': {
            'sourceName': p.sourceName,
            'recordingMethod': p.recordingMethod.name,
          },
        });
      }

      _syncStatusMessage = 'Uploading ${records.length} record${records.length == 1 ? '' : 's'}...';
      notifyListeners();

      final res = await _dataSource.syncHealthData({
        'provider': provider.apiKey,
        'syncType': isInitial ? 'INITIAL' : 'MANUAL',
        'records': records,
      });

      if (res != null && res['status'] == 'SUCCESS') {
        _syncStatusMessage = records.isEmpty
            ? 'No new health data found on this device.'
            : 'Synced ${records.length} record${records.length == 1 ? '' : 's'}.';
        await refresh();
        return true;
      }
      _lastError = 'EBIC could not process the sync. Please try again.';
      return false;
    } catch (e) {
      debugPrint('[HealthProviderManager] Sync error: $e');
      _lastError = 'Could not read health data from ${provider.displayName}.';
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
