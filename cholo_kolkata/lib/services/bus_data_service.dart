import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/models.dart';
import 'kolkata_stops.dart';

class _OfflineRouteRecord {
  final int id;
  final String routeNo;
  final String routeNoCompact;
  final String origin;
  final String destination;
  final String routeName;
  final String busType;
  final String category;
  final String timetable;
  final List<String> stops;
  final List<String> stopsLower;

  _OfflineRouteRecord({
    required this.id,
    required this.routeNo,
    required this.routeNoCompact,
    required this.origin,
    required this.destination,
    required this.routeName,
    required this.busType,
    required this.category,
    required this.timetable,
    required this.stops,
    required this.stopsLower,
  });
}

class BusDataService {
  static final BusDataService _instance = BusDataService._internal();
  factory BusDataService() => _instance;
  BusDataService._internal();

  bool _isInitialized = false;
  Map<String, List<dynamic>> _routesMap = {};
  final List<_OfflineRouteRecord> _allRecords = [];
  final Map<int, _OfflineRouteRecord> _byId = {};

  // Top fallback routes built-in if asset bundle cannot be loaded
  static const Map<String, List<Map<String, dynamic>>> fallbackRoutes = {
    '215A': [
      {
        'id': 2001,
        'r': '215A',
        'f': 'Howrah Station',
        't': 'Sector V (Saltlake)',
        's': [
          'Howrah Station', 'Posta Bazar', 'Nimtala', 'Jorabagan', 'Ahiritola',
          'BK Paul More', 'Sovabazar', 'Hatibagan', 'Khanna Cinema', 'Ultadanga',
          'Saltlake PNB', 'Saltlake 4no. Tank', 'Baisakhi More', 'Saltlake 7no. Tank',
          'Saltlake 206', 'Saltlake 9no. Tank', 'Karunamoyee', 'Wipro More',
          'SDF More', 'College More', 'Sector V'
        ]
      },
      {
        'id': 2002,
        'r': '215A',
        'f': 'Sector V (Saltlake)',
        't': 'Howrah Station',
        's': [
          'Sector V', 'SDF More', 'College More', 'Wipro More', 'Karunamoyee',
          'Saltlake 9no. Tank', 'Saltlake 206', 'Saltlake 7no. Tank', 'Baisakhi More',
          'Saltlake 4no. Tank', 'Saltlake PNB', 'Ultadanga', 'Khanna Cinema',
          'Hatibagan', 'Sovabazar', 'BK Paul More', 'Ahiritola', 'Jorabagan',
          'Malapara', 'Barabazar', 'Howrah Station'
        ]
      }
    ],
    '44A': [
      {
        'id': 2003,
        'r': '44A',
        'f': 'Howrah Station',
        't': 'Sector V (Saltlake)',
        's': [
          'Howrah Station', 'Barabazar', 'MG Road', 'Sealdah', 'Beliaghata',
          'Phoolbagan', 'Kankurgachi', 'Hudco', 'Ultadanga', 'Saltlake PNB',
          'Karunamoyee', 'Wipro More', 'College More', 'SDF More', 'Sector V'
        ]
      }
    ],
  };

  static const List<Map<String, dynamic>> _transferHubs = [
    {'label': 'Howrah Station', 'terms': ['howrah']},
    {'label': 'Esplanade', 'terms': ['esplanade']},
    {'label': 'Sealdah Station', 'terms': ['sealdah']},
    {'label': 'Ultadanga', 'terms': ['ultadanga']},
    {'label': 'Sector V', 'terms': ['sector v']},
    {'label': 'Gariahat', 'terms': ['gariahat']},
    {'label': 'Ruby Hospital', 'terms': ['ruby']},
    {'label': 'Shyambazar', 'terms': ['shyambazar']},
    {'label': 'Exide / Rabindra Sadan', 'terms': ['exide', 'rabindra sadan']},
  ];

  int get totalRoutesCount => _allRecords.length;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final routesJson = await rootBundle.loadString('assets/kolkata_bus_routes.json');
      String? stopsJson;
      try {
        stopsJson = await rootBundle.loadString('assets/kolkata_stops.json');
      } catch (_) {}
      loadFromJsonStrings(routesJson, stopsJson);
    } catch (_) {
      _routesMap = fallbackRoutes.map((k, v) => MapEntry(k, v));
      _rebuildIndexes();
      _isInitialized = true;
    }
  }

  /// Loads routes and stops directly from JSON strings (used by init and unit tests).
  void loadFromJsonStrings(String routesJson, [String? stopsJson]) {
    final Map<String, dynamic> decoded = json.decode(routesJson);
    _routesMap = decoded.map((k, v) => MapEntry(k, v as List<dynamic>));
    _rebuildIndexes();

    if (stopsJson != null && stopsJson.isNotEmpty) {
      final List<dynamic> rawStops = json.decode(stopsJson) as List<dynamic>;
      final parsedStops = rawStops
          .map((item) {
            final map = item as Map<String, dynamic>;
            final name = (map['n'] ?? map['stop_name'] ?? '').toString().trim();
            final count = (map['c'] is num)
                ? (map['c'] as num).toInt()
                : ((map['routes_count'] is num) ? (map['routes_count'] as num).toInt() : 0);
            return BusStopItem(
              name: name,
              routesCount: count,
              subtitle: count > 0 ? '$count+ connecting routes' : 'Kolkata Transit Stop',
            );
          })
          .where((s) => s.name.isNotEmpty)
          .toList();
      KolkataStops.setAllStops(parsedStops);
    }

    _isInitialized = true;
  }

  void _rebuildIndexes() {
    _allRecords.clear();
    _byId.clear();

    for (final entry in _routesMap.entries) {
      for (final raw in entry.value) {
        final v = raw as Map<String, dynamic>;
        final rNo = (v['r'] ?? entry.key).toString();
        final origin = (v['f'] ?? '').toString();
        final dest = (v['t'] ?? '').toString();
        final rawStops = (v['s'] as List? ?? []).map((e) => e.toString()).toList();
        if (rawStops.isEmpty) continue;

        final id = (v['id'] is num)
            ? (v['id'] as num).toInt()
            : '$rNo::$origin::$dest'.hashCode.abs();
        final isAc = rNo.toUpperCase().startsWith('AC') ||
            (v['bt']?.toString().toLowerCase().contains('ac') ?? false);
        final busType = (v['bt']?.toString().isNotEmpty ?? false)
            ? v['bt'].toString()
            : (isAc ? 'AC Electric Bus' : 'City Bus');
        final category = (v['cat']?.toString().isNotEmpty ?? false)
            ? v['cat'].toString()
            : (isAc ? 'AC Electric Service' : 'West Bengal Transport Corporation');
        final routeName = (v['rn']?.toString().isNotEmpty ?? false)
            ? v['rn'].toString()
            : rawStops.take(5).join(', ');
        final timetable = (v['tt'] ?? '').toString();

        final rec = _OfflineRouteRecord(
          id: id,
          routeNo: rNo,
          routeNoCompact: rNo.toUpperCase().replaceAll(RegExp(r'[\s\-]+'), ''),
          origin: origin,
          destination: dest,
          routeName: routeName,
          busType: busType,
          category: category,
          timetable: timetable,
          stops: rawStops,
          stopsLower: rawStops.map((s) => s.toLowerCase()).toList(),
        );
        _allRecords.add(rec);
        _byId[id] = rec;
      }
    }
  }

  /// Official WB bus fare slab calculation matching backend api.php
  static int calculateBusFare(String busType, int stopsCount) {
    final stops = stopsCount < 1 ? 1 : stopsCount;
    final t = busType.toLowerCase();
    if (t.contains('ac') || t.contains('volvo')) {
      if (stops <= 5) return 25;
      if (stops <= 12) return 35;
      if (stops <= 20) return 45;
      return 60;
    }
    if (stops <= 4) return 10;
    if (stops <= 8) return 12;
    if (stops <= 14) return 15;
    if (stops <= 20) return 18;
    return 20;
  }

  /// Expands user search query into normalized terms & common Kolkata stop aliases
  static List<String> _expandStopTerms(String raw) {
    final cleanedParen = raw.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ').trim().toLowerCase();
    final trimmed = raw.trim().toLowerCase();
    if (cleanedParen.isEmpty && trimmed.isEmpty) return const [];

    final terms = <String>{};
    if (cleanedParen.isNotEmpty) terms.add(cleanedParen);
    if (trimmed.isNotEmpty && trimmed != cleanedParen) terms.add(trimmed);

    const aliasMap = <String, List<String>>{
      'sector 5': ['sector v', 'sector 5'],
      'sector-5': ['sector v', 'sector 5'],
      'saltlake': ['sector v', 'saltlake', 'salt lake'],
      'salt lake': ['sector v', 'saltlake', 'salt lake'],
      'salt lake sector v': ['sector v'],
      'howrah stn': ['howrah station', 'howrah'],
      'howrah station': ['howrah station', 'howrah'],
      'hwh': ['howrah'],
      'sealdah stn': ['sealdah station', 'sealdah'],
      'sealdah station': ['sealdah station', 'sealdah'],
      'sda': ['sealdah'],
      'airport': ['airport'],
      'nscbi airport': ['airport'],
      'nscbia': ['airport'],
      'exide': ['exide', 'rabindra sadan'],
      'rabindra sadan': ['rabindra sadan', 'exide'],
      'bbd bagh': ['bbd bagh', 'bbd bag', 'dalhousie'],
      'bbd bag': ['bbd bag', 'bbd bagh', 'dalhousie'],
      'dalhousie': ['dalhousie', 'bbd bag', 'bbd bagh'],
      'ruby hospital': ['ruby hospital', 'ruby'],
      'ruby': ['ruby'],
      'jadavpur': ['jadavpur'],
      'garia': ['garia'],
      'kavi subhash': ['kavi subhash', 'new garia', 'garia'],
      'beleghata': ['beleghata', 'beliaghata'],
      'beliaghata': ['beliaghata', 'beleghata'],
      'kidderpore': ['kidderpore', 'khidderpore'],
      'khidderpore': ['khidderpore', 'kidderpore'],
      'dakshineswar': ['dakshineswar', 'dakshineshwar'],
      'dakshineshwar': ['dakshineshwar', 'dakshineswar'],
      'new town': ['new town', 'newtown'],
      'newtown': ['newtown', 'new town'],
      'ajay nagar': ['ajay nagar', 'ajaynagar'],
      'ajaynagar': ['ajaynagar', 'ajay nagar'],
      'majerhat': ['majerhat', 'majherhat'],
      'majherhat': ['majherhat', 'majerhat'],
      'chandni chowk': ['chandni chowk', 'chandni market', 'chandni'],
    };

    final expanded = aliasMap[cleanedParen];
    if (expanded != null) {
      terms.addAll(expanded);
    }
    return terms.toList();
  }

  static int _findStopIndex(List<String> stopsLower, List<String> terms, {int startAt = 0}) {
    for (int i = startAt; i < stopsLower.length; i++) {
      final stop = stopsLower[i];
      for (final term in terms) {
        if (stop.contains(term)) {
          return i;
        }
      }
    }
    return -1;
  }

  /// Get stops list for a route with 0ms latency
  List<Map<String, dynamic>> getRouteStops(String routeNo, {int? routeId, String? from, String? to}) {
    final rec = _findRecord(routeNo, routeId: routeId, from: from, to: to);
    if (rec == null) return [];
    return List.generate(rec.stops.length, (i) {
      return {
        'stop_order': i + 1,
        'stop_name': rec.stops[i],
      };
    });
  }

  _OfflineRouteRecord? _findRecord(String routeNo, {int? routeId, String? from, String? to}) {
    if (routeId != null && _byId.containsKey(routeId)) {
      return _byId[routeId];
    }

    final key = routeNo.toUpperCase().replaceAll(' ', '').trim();
    final compactKey = routeNo.toUpperCase().replaceAll(RegExp(r'[\s\-]+'), '');
    final rawMatches = <_OfflineRouteRecord>[];

    for (final rec in _allRecords) {
      if (rec.routeNo.toUpperCase().replaceAll(' ', '') == key ||
          rec.routeNoCompact == compactKey) {
        rawMatches.add(rec);
      }
    }
    if (rawMatches.isEmpty) {
      for (final rec in _allRecords) {
        if (rec.routeNoCompact.contains(compactKey) || compactKey.contains(rec.routeNoCompact)) {
          rawMatches.add(rec);
        }
      }
    }
    if (rawMatches.isEmpty) return null;

    if (from != null && from.isNotEmpty) {
      final fromTerms = _expandStopTerms(from);
      final toTerms = (to != null && to.isNotEmpty) ? _expandStopTerms(to) : <String>[];
      for (final rec in rawMatches) {
        final fIdx = _findStopIndex(rec.stopsLower, fromTerms);
        if (fIdx != -1) {
          if (toTerms.isEmpty) return rec;
          final tIdx = _findStopIndex(rec.stopsLower, toTerms, startAt: fIdx + 1);
          if (tIdx != -1) return rec;
        }
      }
      for (final rec in rawMatches) {
        final fLow = rec.origin.toLowerCase();
        if (fromTerms.any((t) => fLow.contains(t))) {
          return rec;
        }
      }
    }

    return rawMatches.first;
  }

  /// Instant 0ms Route Details & Timeline for LiveTrackScreen
  Map<String, dynamic>? getRouteDetails(
    String routeNo, {
    int? routeId,
    String? from,
    String? to,
    String? busType,
  }) {
    final rec = _findRecord(routeNo, routeId: routeId, from: from, to: to);
    if (rec == null) return null;

    final stops = List.generate(rec.stops.length, (i) {
      return {
        'stop_order': i + 1,
        'stop_name': rec.stops[i],
      };
    });

    final effType = (busType != null && busType.isNotEmpty) ? busType : rec.busType;
    final fare = calculateBusFare(effType, stops.length);

    return {
      'route': {
        'id': rec.id,
        'route_no': rec.routeNo,
        'origin': rec.origin.isNotEmpty ? rec.origin : stops.first['stop_name'].toString(),
        'destination': rec.destination.isNotEmpty ? rec.destination : stops.last['stop_name'].toString(),
        'route_name': rec.routeName,
        'category': rec.category,
        'bus_type': effType,
        'timetable': rec.timetable,
        'total_stops': stops.length,
        'stops_between': stops.length,
        'estimated_fare': fare,
        'fare_text': '₹$fare',
        'stops': stops,
      },
      'stops': stops,
    };
  }

  /// Instant 0ms offline search between two stops (or by bus number if `to` is empty)
  List<BusRoute> searchRoutes(String from, String to, {int limit = 80}) {
    if (from.trim().isEmpty) return [];
    if (to.trim().isEmpty) {
      return searchBusNumbers(from, uniqueByRouteNo: false, limit: limit);
    }

    final fromTerms = _expandStopTerms(from);
    final toTerms = _expandStopTerms(to);
    if (fromTerms.isEmpty || toTerms.isEmpty) return [];

    final List<BusRoute> results = [];
    final Set<String> addedKeys = {};

    for (final rec in _allRecords) {
      final fIdx = _findStopIndex(rec.stopsLower, fromTerms);
      if (fIdx == -1) continue;
      final tIdx = _findStopIndex(rec.stopsLower, toTerms, startAt: fIdx + 1);
      if (tIdx == -1) continue;

      final uniq = '${rec.routeNo}::${rec.origin}::${rec.destination}';
      if (addedKeys.contains(uniq)) continue;
      addedKeys.add(uniq);

      final stopsBetween = tIdx - fIdx;
      final fare = calculateBusFare(rec.busType, stopsBetween);

      results.add(
        BusRoute(
          id: rec.id,
          routeNo: rec.routeNo,
          routeName: rec.routeName,
          origin: rec.origin,
          destination: rec.destination,
          category: rec.category,
          busType: rec.busType,
          totalStops: rec.stops.length,
          stopsBetween: stopsBetween,
          fromStop: rec.stops[fIdx],
          toStop: rec.stops[tIdx],
          estimatedFare: fare,
          fareText: '₹$fare',
        ),
      );
    }

    results.sort((a, b) {
      final cmp = (a.stopsBetween ?? 999).compareTo(b.stopsBetween ?? 999);
      if (cmp != 0) return cmp;
      return a.routeNo.compareTo(b.routeNo);
    });
    return results.take(limit).toList();
  }

  /// Instant 0ms offline 1-Transfer route finder via Kolkata transit hubs
  List<TransferRoute> searchTransfers(String from, String to, {int maxTransfers = 4}) {
    final fromTerms = _expandStopTerms(from);
    final toTerms = _expandStopTerms(to);
    if (fromTerms.isEmpty || toTerms.isEmpty) return [];

    final List<TransferRoute> transfers = [];

    for (final hub in _transferHubs) {
      final hubLabel = hub['label'] as String;
      final hubTerms = (hub['terms'] as List<String>);

      // Skip hub if it matches departure or destination
      if (hubTerms.any((h) => fromTerms.any((f) => f.contains(h) || h.contains(f))) ||
          hubTerms.any((h) => toTerms.any((t) => t.contains(h) || h.contains(t)))) {
        continue;
      }

      // Find shortest Leg 1: From -> Hub
      _OfflineRouteRecord? bestLeg1;
      int bestLeg1FromIdx = -1;
      int bestLeg1HubIdx = -1;
      int bestLeg1Stops = 9999;

      for (final rec in _allRecords) {
        final fIdx = _findStopIndex(rec.stopsLower, fromTerms);
        if (fIdx == -1) continue;
        final hIdx = _findStopIndex(rec.stopsLower, hubTerms, startAt: fIdx + 1);
        if (hIdx == -1) continue;
        final diff = hIdx - fIdx;
        if (diff < bestLeg1Stops) {
          bestLeg1Stops = diff;
          bestLeg1 = rec;
          bestLeg1FromIdx = fIdx;
          bestLeg1HubIdx = hIdx;
        }
      }
      if (bestLeg1 == null) continue;

      // Find shortest Leg 2: Hub -> To (different route)
      _OfflineRouteRecord? bestLeg2;
      int bestLeg2HubIdx = -1;
      int bestLeg2ToIdx = -1;
      int bestLeg2Stops = 9999;

      for (final rec in _allRecords) {
        if (rec.routeNoCompact == bestLeg1.routeNoCompact) continue;
        final hIdx = _findStopIndex(rec.stopsLower, hubTerms);
        if (hIdx == -1) continue;
        final tIdx = _findStopIndex(rec.stopsLower, toTerms, startAt: hIdx + 1);
        if (tIdx == -1) continue;
        final diff = tIdx - hIdx;
        if (diff < bestLeg2Stops) {
          bestLeg2Stops = diff;
          bestLeg2 = rec;
          bestLeg2HubIdx = hIdx;
          bestLeg2ToIdx = tIdx;
        }
      }
      if (bestLeg2 == null) continue;

      final fare1 = calculateBusFare(bestLeg1.busType, bestLeg1Stops);
      final fare2 = calculateBusFare(bestLeg2.busType, bestLeg2Stops);
      final totalFare = fare1 + fare2;
      final totalStops = bestLeg1Stops + bestLeg2Stops;
      final totalTime = (totalStops * 3.5 + 8).round();

      transfers.add(
        TransferRoute(
          hubName: hubLabel,
          leg1: TransferLeg(
            id: bestLeg1.id,
            routeNo: bestLeg1.routeNo,
            routeName: bestLeg1.routeName,
            busType: bestLeg1.busType,
            fromStop: bestLeg1.stops[bestLeg1FromIdx],
            toStop: bestLeg1.stops[bestLeg1HubIdx],
            stops: bestLeg1Stops,
            fare: fare1,
          ),
          leg2: TransferLeg(
            id: bestLeg2.id,
            routeNo: bestLeg2.routeNo,
            routeName: bestLeg2.routeName,
            busType: bestLeg2.busType,
            fromStop: bestLeg2.stops[bestLeg2HubIdx],
            toStop: bestLeg2.stops[bestLeg2ToIdx],
            stops: bestLeg2Stops,
            fare: fare2,
          ),
          totalStops: totalStops,
          totalTimeMins: totalTime,
          totalFare: totalFare,
          fareText: '₹$totalFare',
        ),
      );
    }

    transfers.sort((a, b) => a.totalStops.compareTo(b.totalStops));
    return transfers.take(maxTransfers).toList();
  }

  /// Instant 0ms bus number / route name lookup across all 2,172 routes
  List<BusRoute> searchBusNumbers(
    String query, {
    bool uniqueByRouteNo = true,
    int limit = 40,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final qUpper = trimmed.toUpperCase();
    final qCompact = qUpper.replaceAll(RegExp(r'[\s\-]+'), '');
    final qLower = trimmed.toLowerCase();

    final exact = <_OfflineRouteRecord>[];
    final prefix = <_OfflineRouteRecord>[];
    final contains = <_OfflineRouteRecord>[];
    final nameMatch = <_OfflineRouteRecord>[];

    for (final rec in _allRecords) {
      final rUpper = rec.routeNo.toUpperCase();
      if (rUpper == qUpper || rec.routeNoCompact == qCompact) {
        exact.add(rec);
      } else if (rUpper.startsWith(qUpper) || rec.routeNoCompact.startsWith(qCompact)) {
        prefix.add(rec);
      } else if (rUpper.contains(qUpper) || rec.routeNoCompact.contains(qCompact)) {
        contains.add(rec);
      } else if (rec.routeName.toLowerCase().contains(qLower) ||
          rec.origin.toLowerCase().contains(qLower) ||
          rec.destination.toLowerCase().contains(qLower)) {
        nameMatch.add(rec);
      }
    }

    final ordered = <_OfflineRouteRecord>[...exact, ...prefix, ...contains, ...nameMatch];
    final List<BusRoute> matches = [];
    final Set<String> seen = {};

    for (final rec in ordered) {
      final dedupKey = uniqueByRouteNo
          ? rec.routeNo.toUpperCase()
          : '${rec.id}::${rec.routeNo}::${rec.origin}::${rec.destination}';
      if (seen.contains(dedupKey)) continue;
      seen.add(dedupKey);

      final fare = calculateBusFare(rec.busType, rec.stops.length);
      matches.add(
        BusRoute(
          id: rec.id,
          routeNo: rec.routeNo,
          routeName: rec.routeName,
          origin: rec.origin,
          destination: rec.destination,
          category: rec.category,
          busType: rec.busType,
          totalStops: rec.stops.length,
          estimatedFare: fare,
          fareText: '₹$fare',
        ),
      );
      if (matches.length >= limit) break;
    }
    return matches;
  }
}
