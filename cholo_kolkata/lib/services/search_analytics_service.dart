import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'kolkata_geo.dart';

class SilentLocationSnapshot {
  final double lat;
  final double lng;
  final String locationName;

  const SilentLocationSnapshot({
    required this.lat,
    required this.lng,
    required this.locationName,
  });
}

class SearchAnalyticsService {
  static final SearchAnalyticsService _instance = SearchAnalyticsService._internal();
  factory SearchAnalyticsService() => _instance;
  SearchAnalyticsService._internal();

  static const String _queueKey = 'pending_search_analytics_v1';
  static const String _deviceIdKey = 'analytics_device_id_v1';
  static const int _maxQueueSize = 500;

  final Random _rng = Random();
  bool _isFlushing = false;
  Timer? _debounceTimer;
  SilentLocationSnapshot? _cachedLocation;
  DateTime? _cachedAt;

  /// Returns an anonymous persistent device identifier (no PII).
  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = 'ck_${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(900000) + 100000}';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  /// Resolves the closest known Kolkata landmark within 6 km of [lat], [lng].
  static String resolveNearestLocationName(double lat, double lng) {
    String bestName = '';
    double bestDistKm = 6.0;
    const p = 0.017453292519943295;

    for (final entry in KolkataGeo.landmarkCoordinates.entries) {
      final dLat = (entry.value.latitude - lat) * p;
      final dLon = (entry.value.longitude - lng) * p;
      final a = 0.5 -
          cos(dLat) / 2 +
          cos(lat * p) * cos(entry.value.latitude * p) * (1 - cos(dLon)) / 2;
      final km = 12742 * asin(sqrt(a));
      if (km < bestDistKm) {
        bestDistKm = km;
        bestName = entry.key
            .split(' ')
            .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
      }
    }
    return bestName;
  }

  /// Silently reads GPS location only if permission is already granted (never prompts).
  Future<SilentLocationSnapshot?> getSilentLocation() async {
    if (_cachedLocation != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!).inMinutes < 3) {
      return _cachedLocation;
    }

    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.whileInUse && perm != LocationPermission.always) {
        return null;
      }

      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(milliseconds: 1500),
        ),
      );

      final snap = SilentLocationSnapshot(
        lat: pos.latitude,
        lng: pos.longitude,
        locationName: resolveNearestLocationName(pos.latitude, pos.longitude),
      );
      _cachedLocation = snap;
      _cachedAt = DateTime.now();
      return snap;
    } catch (_) {
      return null;
    }
  }

  /// Reads all queued local search events waiting for upload.
  Future<List<Map<String, dynamic>>> getPendingSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Records a Bus or Metro search locally and schedules a silent batch upload.
  Future<void> recordSearch({
    required String mode,
    String from = '',
    String to = '',
    String busNo = '',
    int resultsCount = 0,
    bool autoFlush = true,
  }) async {
    if (from.trim().isEmpty && to.trim().isEmpty && busNo.trim().isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = await getPendingSearches();

      final loc = await getSilentLocation();
      final localId = '${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(9999)}';

      queue.add({
        'local_id': localId,
        'mode': mode,
        'from': from.trim(),
        'to': to.trim(),
        'bus_no': busNo.trim(),
        'results_count': resultsCount,
        if (loc != null) 'lat': loc.lat,
        if (loc != null) 'lng': loc.lng,
        if (loc != null && loc.locationName.isNotEmpty) 'location_name': loc.locationName,
        'searched_at': DateTime.now().toIso8601String(),
      });

      if (queue.length > _maxQueueSize) {
        queue.removeRange(0, queue.length - _maxQueueSize);
      }

      await prefs.setString(_queueKey, json.encode(queue));

      if (autoFlush) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 3), () {
          flushQueue();
        });
      }
    } catch (_) {}
  }

  /// Uploads all locally queued searches in one batch and deletes confirmed records locally.
  Future<int> flushQueue({
    Future<List<String>?> Function(String deviceId, List<Map<String, dynamic>> batch)? uploader,
  }) async {
    if (_isFlushing) return 0;
    _isFlushing = true;

    try {
      final pending = await getPendingSearches();
      if (pending.isEmpty) return 0;

      final deviceId = await getOrCreateDeviceId();
      final batch = pending.take(100).toList();

      final ackedIds = uploader != null
          ? await uploader(deviceId, batch)
          : await ApiService().uploadSearchAnalyticsBatch(
              deviceId: deviceId,
              searches: batch,
            );

      if (ackedIds == null || ackedIds.isEmpty) {
        return 0;
      }

      final ackSet = ackedIds.toSet();
      final prefs = await SharedPreferences.getInstance();
      final latestQueue = await getPendingSearches();
      latestQueue.removeWhere((item) => ackSet.contains(item['local_id']?.toString() ?? ''));
      if (latestQueue.isEmpty) {
        await prefs.remove(_queueKey);
      } else {
        await prefs.setString(_queueKey, json.encode(latestQueue));
      }
      return ackedIds.length;
    } catch (_) {
      return 0;
    } finally {
      _isFlushing = false;
    }
  }
}
