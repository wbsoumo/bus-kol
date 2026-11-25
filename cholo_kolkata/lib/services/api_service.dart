import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import '../models/models.dart';
import 'metro_service.dart';
import 'kolkata_stops.dart';

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
  Future<Map<String, dynamic>> _secureGet(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

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

  /// 8. Post Community Chat Alert
  Future<bool> postChatMessage({
    required String channel,
    required String userName,
    required String routeRef,
    required String statusTag,
    required String message,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/post');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'channel': channel,
          'user_name': userName,
          'route_ref': routeRef,
          'status_tag': statusTag,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error posting chat message: $e');
      return false;
    }
  }

  /// 9. OTA Dynamic Background Route Sync (No APK updates required)
  Future<Map<String, dynamic>> checkBackgroundSync(String currentVersion) async {
    try {
      final endpoint = '/api/sync?version=${Uri.encodeComponent(currentVersion)}';
      return await _secureGet(endpoint);
    } catch (e) {
      return {'has_updates': false, 'error': e.toString()};
    }
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

