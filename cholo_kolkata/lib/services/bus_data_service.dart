import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/models.dart';

class BusDataService {
  static final BusDataService _instance = BusDataService._internal();
  factory BusDataService() => _instance;
  BusDataService._internal();

  bool _isInitialized = false;
  Map<String, List<dynamic>> _routesMap = {};

  // Top fallback routes built-in for 0.0ms instant startup availability
  static const Map<String, List<Map<String, dynamic>>> fallbackRoutes = {
    '215A': [
      {
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
    '215A/1': [
      {
        'r': '215A/1',
        'f': 'Howrah Station',
        't': 'Sector V (Saltlake)',
        's': [
          'Howrah Station', 'Barabazar', 'MG Road', 'Girish Park', 'Vivekananda Road',
          'Maniktala', 'Khanna Cinema', 'Ultadanga', 'Saltlake PNB', 'Saltlake C.A. Block',
          'City Center 1', 'Bikash Bhawan', 'Karunamoyee', 'Wipro More', 'College More',
          'SDF More', 'Sector V'
        ]
      },
      {
        'r': '215A/1',
        'f': 'Sector V (Saltlake)',
        't': 'Howrah Station',
        's': [
          'Sector V', 'SDF More', 'College More', 'Wipro More', 'Karunamoyee',
          'Bikash Bhawan', 'City Center 1', 'Saltlake C.A. Block', 'Saltlake PNB',
          'Ultadanga', 'Khanna Cinema', 'Maniktala', 'Vivekananda Road', 'Girish Park',
          'MG Road', 'Barabazar', 'Howrah Station'
        ]
      }
    ],
    '44A': [
      {
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
    '12C': [
      {
        'r': '12C',
        'f': 'Pailan',
        't': 'Howrah Station',
        's': [
          'Pailan', 'Joka Bridge', 'Thakurpukur', 'Shilpara', 'Sakher Bazar',
          'Behala Chowrasta', 'Behala 14no.', 'Taratala', 'Brace Bridge', 'Hide Road',
          'BNR Hospital', 'Babubazar', 'Khidderpore', 'Hastings', 'Fort William',
          'Esplanade', 'Dalhousie', 'Barabazar', 'Howrah Station'
        ]
      }
    ],
    'S-12': [
      {
        'r': 'S-12',
        'f': 'Newtown',
        't': 'Howrah Station',
        's': [
          'Newtown', 'DLF 1', 'College More', 'SDF More', 'Karunamoyee',
          'Ultadanga', 'Maniktala', 'Girish Park', 'MG Road', 'Howrah Station'
        ]
      }
    ],
    'AC-12': [
      {
        'r': 'AC-12',
        'f': 'Shapoorji',
        't': 'Howrah Station',
        's': [
          'Shapoorji', 'Eco Space', 'Newtown', 'Karunamoyee', 'Ultadanga',
          'Khanna Cinema', 'Sovabazar', 'MG Road', 'Barabazar', 'Howrah Station'
        ]
      }
    ]
  };

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final jsonString = await rootBundle.loadString('assets/kolkata_bus_routes.json');
      final Map<String, dynamic> decoded = json.decode(jsonString);
      _routesMap = decoded.map((k, v) => MapEntry(k, v as List<dynamic>));
      _isInitialized = true;
    } catch (_) {
      _routesMap = fallbackRoutes.map((k, v) => MapEntry(k, v));
      _isInitialized = true;
    }
  }

  /// Get stops list for a route with 0ms latency
  List<Map<String, dynamic>> getRouteStops(String routeNo, {String? from, String? to}) {
    final key = routeNo.toUpperCase().replaceAll(' ', '').trim();
    List<dynamic>? variants = _routesMap[key];

    if (variants == null || variants.isEmpty) {
      variants = fallbackRoutes[key];
    }

    if (variants == null || variants.isEmpty) {
      for (final entry in _routesMap.entries) {
        if (entry.key == key || entry.key.contains(key) || key.contains(entry.key)) {
          variants = entry.value;
          break;
        }
      }
    }

    if (variants == null || variants.isEmpty) {
      return [];
    }

    // Pick best matching direction
    Map<String, dynamic> chosen = variants.first as Map<String, dynamic>;
    if (from != null && from.isNotEmpty) {
      final fromLow = from.toLowerCase();
      for (final v in variants) {
        final f = (v['f'] ?? '').toString().toLowerCase();
        final sList = (v['s'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
        if (f.contains(fromLow) || (sList.isNotEmpty && sList.first.contains(fromLow))) {
          chosen = v as Map<String, dynamic>;
          break;
        }
      }
    }

    final List<dynamic> rawStops = chosen['s'] as List<dynamic>? ?? [];
    return List.generate(rawStops.length, (i) {
      return {
        'stop_order': i + 1,
        'stop_name': rawStops[i].toString(),
      };
    });
  }

  /// Instant 0ms Route Details & Timeline for LiveTrackScreen
  Map<String, dynamic>? getRouteDetails(String routeNo, {String? from, String? to, String? busType}) {
    final stops = getRouteStops(routeNo, from: from, to: to);
    if (stops.isEmpty) return null;

    final origin = (from != null && from.isNotEmpty) ? from : stops.first['stop_name'].toString();
    final dest = (to != null && to.isNotEmpty) ? to : stops.last['stop_name'].toString();

    final isAc = routeNo.toUpperCase().startsWith('AC') || (busType?.toLowerCase().contains('ac') ?? false);
    final fare = isAc ? 20 + (stops.length * 1.1).round() : 10 + (stops.length * 0.75).round();

    return {
      'route': {
        'id': routeNo.hashCode.abs(),
        'route_no': routeNo,
        'origin': origin,
        'destination': dest,
        'route_name': stops.map((s) => s['stop_name']).take(5).join(', '),
        'category': isAc ? 'AC Electric / Volvo Service' : 'West Bengal Transport Corporation',
        'bus_type': busType ?? (isAc ? 'AC Electric Bus' : 'City Bus'),
        'total_stops': stops.length,
        'stops_between': stops.length,
        'estimated_fare': fare,
        'fare_text': '₹$fare',
        'stops': stops,
      },
      'stops': stops,
    };
  }

  /// Instant 0ms offline search between two stops
  List<BusRoute> searchRoutes(String from, String to) {
    if (from.trim().isEmpty || to.trim().isEmpty) return [];

    final fromLow = from.trim().toLowerCase();
    final toLow = to.trim().toLowerCase();
    final List<BusRoute> results = [];
    final Set<String> addedKeys = {};

    final mapToSearch = _routesMap.isNotEmpty ? _routesMap : fallbackRoutes;

    for (final entry in mapToSearch.entries) {
      for (final v in entry.value) {
        final stops = (v['s'] as List?)?.map((s) => s.toString().toLowerCase()).toList() ?? [];
        int fIdx = -1;
        int tIdx = -1;

        for (int i = 0; i < stops.length; i++) {
          if (fIdx == -1 && stops[i].contains(fromLow)) {
            fIdx = i;
          }
          if (stops[i].contains(toLow)) {
            tIdx = i;
          }
        }

        if (fIdx != -1 && tIdx != -1 && fIdx < tIdx) {
          final rNo = v['r'].toString();
          final orig = v['f'].toString();
          final dest = v['t'].toString();
          final uniq = '$rNo::$orig::$dest';

          if (!addedKeys.contains(uniq)) {
            addedKeys.add(uniq);
            final stopsBetween = tIdx - fIdx;
            final isAc = rNo.toUpperCase().startsWith('AC');
            final fare = isAc ? 20 + (stopsBetween * 1.1).round() : 10 + (stopsBetween * 0.75).round();

            results.add(
              BusRoute(
                id: rNo.hashCode.abs(),
                routeNo: rNo,
                routeName: (v['s'] as List).take(5).join(', '),
                origin: orig,
                destination: dest,
                category: isAc ? 'AC Electric Service' : 'West Bengal Transport Corp',
                busType: isAc ? 'AC Electric Bus' : 'City Bus',
                totalStops: (v['s'] as List).length,
                stopsBetween: stopsBetween,
                estimatedFare: fare,
                fareText: '₹$fare',
              ),
            );
          }
        }
      }
    }

    results.sort((a, b) => (a.stopsBetween ?? 99).compareTo(b.stopsBetween ?? 99));
    return results;
  }

  /// Instant 0ms bus number lookup (e.g. 215, S-12, AC-12, 44)
  List<BusRoute> searchBusNumbers(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toUpperCase().replaceAll(' ', '');
    final List<BusRoute> matches = [];
    final Set<String> added = {};

    final mapToSearch = _routesMap.isNotEmpty ? _routesMap : fallbackRoutes;

    for (final entry in mapToSearch.entries) {
      if (entry.key.contains(q)) {
        for (final v in entry.value) {
          final rNo = v['r'].toString();
          if (!added.contains(rNo)) {
            added.add(rNo);
            final isAc = rNo.toUpperCase().startsWith('AC');
            matches.add(
              BusRoute(
                id: rNo.hashCode.abs(),
                routeNo: rNo,
                routeName: (v['s'] as List).take(5).join(', '),
                origin: v['f'].toString(),
                destination: v['t'].toString(),
                category: isAc ? 'AC Electric' : 'City Bus',
                busType: isAc ? 'AC Electric Bus' : 'City Bus',
                totalStops: (v['s'] as List).length,
                estimatedFare: isAc ? 25 : 12,
                fareText: isAc ? '₹20-₹45' : '₹10-₹25',
              ),
            );
          }
        }
      }
      if (matches.length >= 10) break;
    }
    return matches;
  }
}
