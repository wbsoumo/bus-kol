import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import '../models/models.dart';
import 'bus_data_service.dart';
import 'metro_service.dart';
import 'kolkata_geo.dart';
import 'kolkata_stops.dart';
import 'multi_transit_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Local transit encryption key (32 bytes AES-256)
  static final List<int> _keyBytes = utf8.encode('KolkataTransitSecureKey2026WIMT!');
  final AesGcm _aesGcm = AesGcm.with256bits();

  // Production cPanel domain for CholoKolkata
  static const String productionDomain = 'http://cholokolkata.online';

  // Automatic Host Resolver for Emulator vs Production Device
  String get baseUrl {
    // Connect directly to live production cPanel API
    return productionDomain;
  }

  /// Secure Decryption of AES-GCM 256 Payload (Zero Data Leak)
  Future<dynamic> _decryptPayload(String base64Packed) async {
    final rawBytes = base64.decode(base64Packed);
    if (rawBytes.length < 28) {
      throw Exception('Invalid ciphertext payload');
    }

    // [12 bytes IV] + [Ciphertext + 16 bytes Tag]
    final nonce = rawBytes.sublist(0, 12);
    final ciphertextWithTag = rawBytes.sublist(12);

    final ciphertext = ciphertextWithTag.sublist(0, ciphertextWithTag.length - 16);
    final macBytes = ciphertextWithTag.sublist(ciphertextWithTag.length - 16);

    final secretKey = await _aesGcm.newSecretKeyFromBytes(_keyBytes);
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final decryptedBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    final jsonStr = utf8.decode(decryptedBytes);
    return json.decode(jsonStr);
  }

  /// Helper to fetch and decrypt from secure endpoint
  Future<Map<String, dynamic>> _secureGet(
    String endpoint, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.get(uri).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('Server returned status ${response.statusCode}');
    }

    final wrapper = json.decode(response.body);
    if (wrapper == null || wrapper['p'] == null) {
      throw Exception('Missing secure payload wrapper');
    }

    final decrypted = await _decryptPayload(wrapper['p']);
    return decrypted as Map<String, dynamic>;
  }

  /// 1. Search Buses (Direct + 1-Transfer Multi-Hop)
  Future<Map<String, dynamic>> searchRoutes(String from, String to) async {
    final endpoint = '/api/search?from=${Uri.encodeComponent(from)}&to=${Uri.encodeComponent(to)}';
    final data = await _secureGet(endpoint);

    final directList = (data['routes'] as List? ?? [])
        .map((r) => BusRoute.fromJson(r))
        .toList();

    final transferList = (data['transfer_routes'] as List? ?? [])
        .map((t) => TransferRoute.fromJson(t))
        .toList();

    return {
      'direct': directList,
      'transfers': transferList,
      'from': data['from_query'] ?? from,
      'to': data['to_query'] ?? to,
    };
  }

  /// 2. Stop Autocomplete Suggestions (Merged Instant 0ms Local + Server Database)
  Future<List<BusStopItem>> searchStops(String query) async {
    final local = KolkataStops.searchLocal(query, limit: 12);

    try {
      final endpoint = '/api/stops?q=${Uri.encodeComponent(query)}&limit=15';
      final data = await _secureGet(endpoint).timeout(const Duration(milliseconds: 1500));
      final list = data['stops'] as List? ?? [];

      final Map<String, BusStopItem> merged = {
        for (final item in local) item.name.toLowerCase(): item,
      };

      for (final s in list) {
        final name = (s['stop_name'] ?? '').toString();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        final count = (s['routes_count'] is num) ? (s['routes_count'] as num).toInt() : 0;
        if (!merged.containsKey(key)) {
          merged[key] = BusStopItem(
            name: name,
            routesCount: count,
            subtitle: count > 0 ? '$count+ connecting routes' : 'Kolkata Transit Stop',
          );
        }
      }

      return merged.values.toList();
    } catch (_) {
      return local;
    }
  }

  /// Backward-compatible String list
  Future<List<String>> searchStopNames(String query) async {
    final stops = await searchStops(query);
    return stops.map((s) => s.name).toList();
  }

  /// 2b. Bus Number / Route Autocomplete Suggestions
  Future<List<BusRoute>> searchBusNumbers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final endpoint = '/api/routes?q=${Uri.encodeComponent(query)}&limit=6';
      final data = await _secureGet(endpoint);
      final list = data['routes'] as List? ?? [];
      return list.map((r) => BusRoute.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 3. Route Details and Ordered Stops
  Future<Map<String, dynamic>> getRouteDetails(int routeId) async {
    final endpoint = '/api/routes/$routeId';
    return await _secureGet(endpoint);
  }

  /// 4. Kolkata Metro Corridors (Instant In-Memory Preload + Background Refresh)
  Future<List<MetroLine>> getMetroLines() async {
    try {
      final data = await _secureGet('/api/metro/lines').timeout(const Duration(milliseconds: 1500));
      final lines = data['lines'] as List? ?? [];
      if (lines.isNotEmpty) {
        return lines.map((l) => MetroLine.fromJson(l)).toList();
      }
    } catch (_) {}
    return MetroService.defaultMetroLines;
  }

  /// 5. Kolkata Metro Stations (Instant In-Memory Preload + Background Refresh)
  Future<List<MetroStation>> getMetroStations() async {
    try {
      final data = await _secureGet('/api/metro/stations').timeout(const Duration(milliseconds: 1500));
      final stns = data['stations'] as List? ?? [];
      if (stns.isNotEmpty) {
        return stns.map((s) => MetroStation.fromJson(s)).toList();
      }
    } catch (_) {}
    return MetroService.defaultMetroStations;
  }

  /// 6. Station-to-Station Journey Planner (<1ms offline algorithm + online resilience)
  Future<MetroPlan?> planMetroRoute(String from, String to) async {
    try {
      final endpoint = '/api/metro/plan?from=${Uri.encodeComponent(from)}&to=${Uri.encodeComponent(to)}';
      final data = await _secureGet(endpoint).timeout(const Duration(milliseconds: 1500));
      if (data['plan'] != null) {
        return MetroPlan.fromJson(data['plan']);
      }
    } catch (_) {}
    return MetroService.planJourney(from, to);
  }

  /// 7. Community Chat Feed (m-Indicator style)
  Future<List<ChatMessage>> getChatMessages(String channel) async {
    final endpoint = '/api/chat/messages?channel=${Uri.encodeComponent(channel)}&limit=50';
    try {
      final data = await _secureGet(endpoint);
      final msgs = data['messages'] as List? ?? [];
      return msgs.map((m) => ChatMessage.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Error getting chat messages: $e');
      return [];
    }
  }

  /// 8. Post Community Chat Alert (with optional GPS telemetry; IP captured on server)
  Future<bool> postChatMessage({
    required String channel,
    required String userName,
    required String routeRef,
    required String statusTag,
    required String message,
    double? lat,
    double? lng,
    String? locationName,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/post');
      final payload = <String, dynamic>{
        'channel': channel,
        'user_name': userName,
        'route_ref': routeRef,
        'status_tag': statusTag,
        'message': message,
      };
      if (lat != null && lng != null) {
        payload['lat'] = lat;
        payload['lng'] = lng;
      }
      if (locationName != null && locationName.isNotEmpty) {
        payload['location_name'] = locationName;
      }

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error posting chat message: $e');
      return false;
    }
  }

  /// 8b. Batch Upload Queued Search Analytics (Bus + Metro)
  Future<List<String>?> uploadSearchAnalyticsBatch({
    required String deviceId,
    required List<Map<String, dynamic>> searches,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/analytics/searches');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': deviceId,
          'searches': searches,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return null;
      final wrapper = json.decode(response.body);
      if (wrapper == null || wrapper['p'] == null) return null;
      final decrypted = await _decryptPayload(wrapper['p']) as Map<String, dynamic>;
      if (decrypted['success'] != true) return null;
      final list = decrypted['acked_ids'] as List? ?? [];
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return null;
    }
  }

  /// 9. OTA Dynamic Background Route Sync (Persists into BusDataService offline cache)
  Future<Map<String, dynamic>> checkBackgroundSync(String currentVersion) async {
    try {
      final endpoint = '/api/sync?version=${Uri.encodeComponent(currentVersion)}';
      return await _secureGet(endpoint);
    } catch (e) {
      return {'has_updates': false, 'error': e.toString()};
    }
  }

  /// Downloads the full compressed transit bundle when an OTA update is published
  Future<Map<String, dynamic>> fetchOtaBundle() async {
    return await _secureGet('/api/ota/bundle', timeout: const Duration(seconds: 25));
  }

  /// Checks OTA version/route counts and silently updates Bus, Auto & Stop Coords offline databases
  Future<Map<String, dynamic>> syncOtaInBackground({bool force = false}) async {
    final busData = BusDataService();
    final multi = MultiTransitService();
    final check = await checkBackgroundSync(busData.dataVersion);
    if (check['error'] != null) {
      return {
        'success': false,
        'updated': false,
        'error': check['error'],
        'version': busData.dataVersion,
        'total_routes': busData.totalRoutesCount,
        'total_stops': KolkataStops.totalStopsCount,
        'total_auto_routes': multi.totalAutoRoutesCount,
        'total_stop_coords': KolkataGeo.totalCoordsCount,
      };
    }

    final serverVersion = (check['version'] ?? check['current_version'] ?? busData.dataVersion).toString();
    final serverRoutes = (check['total_routes'] is num) ? (check['total_routes'] as num).toInt() : 0;
    final serverAutoRoutes = (check['total_auto_routes'] is num) ? (check['total_auto_routes'] as num).toInt() : 0;
    final serverCoords = (check['total_stop_coords'] is num) ? (check['total_stop_coords'] as num).toInt() : 0;

    final hasUpdates = check['has_updates'] == true ||
        serverVersion != busData.dataVersion ||
        (serverRoutes > 0 && serverRoutes != busData.totalRoutesCount) ||
        (serverAutoRoutes > 0 && serverAutoRoutes != multi.totalAutoRoutesCount) ||
        (serverCoords > 0 && serverCoords != KolkataGeo.totalCoordsCount);

    if (!hasUpdates && !force) {
      return {
        'success': true,
        'updated': false,
        'version': busData.dataVersion,
        'total_routes': busData.totalRoutesCount,
        'total_stops': KolkataStops.totalStopsCount,
        'total_auto_routes': multi.totalAutoRoutesCount,
        'total_stop_coords': KolkataGeo.totalCoordsCount,
      };
    }

    if (!hasUpdates && force) {
      return {
        'success': true,
        'updated': false,
        'version': serverVersion,
        'total_routes': busData.totalRoutesCount,
        'total_stops': KolkataStops.totalStopsCount,
        'total_auto_routes': multi.totalAutoRoutesCount,
        'total_stop_coords': KolkataGeo.totalCoordsCount,
        'changelog': check['changelog'] ?? 'All routes already up to date.',
      };
    }

    final bundle = await fetchOtaBundle();
    if (bundle['success'] == true) {
      final bundleVer = (bundle['version'] ?? serverVersion).toString();
      bool anyApplied = false;

      // Apply Stop GPS Coordinates first so updated routes resolve accurately
      if (bundle['stop_coords'] is Map && (bundle['stop_coords'] as Map).isNotEmpty) {
        final coordsApplied = await KolkataGeo.applyOtaCoords(
          version: bundleVer,
          coordsJson: json.encode(bundle['stop_coords']),
        );
        if (coordsApplied) anyApplied = true;
      }

      // Apply Auto Routes OTA
      if (bundle['auto_routes'] is List && (bundle['auto_routes'] as List).isNotEmpty) {
        final autoApplied = await multi.applyOtaAutoRoutes(
          version: bundleVer,
          autoJson: json.encode(bundle['auto_routes']),
        );
        if (autoApplied) anyApplied = true;
      }

      // Apply Bus Routes & Bus Stops OTA
      if (bundle['routes'] is Map && (bundle['routes'] as Map).isNotEmpty) {
        final routesJson = json.encode(bundle['routes']);
        final stopsJson = json.encode(bundle['stops'] ?? []);
        final busApplied = await busData.applyOtaBundle(
          version: bundleVer,
          routesJson: routesJson,
          stopsJson: stopsJson,
        );
        if (busApplied) anyApplied = true;
      }

      if (anyApplied) {
        return {
          'success': true,
          'updated': true,
          'version': bundleVer,
          'total_routes': busData.totalRoutesCount,
          'total_stops': KolkataStops.totalStopsCount,
          'total_auto_routes': multi.totalAutoRoutesCount,
          'total_stop_coords': KolkataGeo.totalCoordsCount,
          'changelog': check['changelog'] ??
              'Synced ${busData.totalRoutesCount} bus & ${multi.totalAutoRoutesCount} auto routes offline (v$bundleVer).',
        };
      }
    }

    return {
      'success': false,
      'updated': false,
      'version': busData.dataVersion,
      'total_routes': busData.totalRoutesCount,
      'total_stops': KolkataStops.totalStopsCount,
      'total_auto_routes': multi.totalAutoRoutesCount,
      'total_stop_coords': KolkataGeo.totalCoordsCount,
    };
  }

  /// 9b. App Update Config Check (Force / Optional, Play Store / Direct APK)
  Future<Map<String, dynamic>?> checkAppUpdate() async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final data = await _secureGet('/api/app/update-check', timeout: const Duration(seconds: 8));
        if (data['success'] == true && data['config'] is Map) {
          return Map<String, dynamic>.from(data['config'] as Map);
        }
      } catch (_) {}
    }
    return null;
  }

  /// 10. Crowdsourced "Inside The Bus" Live Location Ping
  Future<bool> sendBusPing({
    required int routeId,
    required String routeNo,
    required double lat,
    required double lng,
    required double speedKmh,
    required String sessionId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/bus/ping');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'route_id': routeId,
          'route_no': routeNo,
          'lat': lat,
          'lng': lng,
          'speed_kmh': speedKmh,
          'session_id': sessionId,
        }),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 11. Fetch Live Buses for Route
  Future<List<Map<String, dynamic>>> getLiveBuses(String routeNo) async {
    try {
      final endpoint = '/api/bus/${Uri.encodeComponent(routeNo)}/live';
      final data = await _secureGet(endpoint);
      final list = data['active_buses'] as List? ?? [];
      return list.map((b) => Map<String, dynamic>.from(b)).toList();
    } catch (_) {
      return [];
    }
  }
}

