import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'bus_data_service.dart';
import 'kolkata_geo.dart';
import 'kolkata_stops.dart';
import 'metro_service.dart';

enum TransitMode { bus, train, auto, ferry, metro }

String transitModeLabel(TransitMode mode) {
  switch (mode) {
    case TransitMode.bus:
      return 'BUS';
    case TransitMode.train:
      return 'TRAIN';
    case TransitMode.auto:
      return 'AUTO';
    case TransitMode.ferry:
      return 'FERRY';
    case TransitMode.metro:
      return 'METRO';
  }
}

class TransitStopPoint {
  final String name;
  final double? lat;
  final double? lon;
  final int travelMins;
  final String irCode;

  const TransitStopPoint({
    required this.name,
    this.lat,
    this.lon,
    this.travelMins = 0,
    this.irCode = '',
  });

  LatLng? get latLng => (lat != null && lon != null) ? LatLng(lat!, lon!) : null;
}

class TransitRouteItem {
  final int id;
  final String routeId;
  final TransitMode mode;
  final String code;
  final String routeName;
  final String operatorName;
  final String origin;
  final String destination;
  final int headwayPeakMins;
  final int headwayOffPeakMins;
  final String firstService;
  final String lastService;
  final int fareMin;
  final int fareMax;
  final double distanceKm;
  final int durationMins;
  final String notes;
  final List<TransitStopPoint> stops;
  final List<String> departures; // Used for suburban train timetable ("HH:MM")
  final int dailyTripsCount;

  const TransitRouteItem({
    required this.id,
    required this.routeId,
    required this.mode,
    required this.code,
    required this.routeName,
    required this.operatorName,
    required this.origin,
    required this.destination,
    required this.headwayPeakMins,
    required this.headwayOffPeakMins,
    required this.firstService,
    required this.lastService,
    required this.fareMin,
    required this.fareMax,
    required this.distanceKm,
    required this.durationMins,
    required this.notes,
    required this.stops,
    this.departures = const [],
    this.dailyTripsCount = 0,
  });

  String get fareText => fareMin == fareMax ? '₹$fareMin' : '₹$fareMin–₹$fareMax';

  String get timingSummary =>
      '$firstService – $lastService • Every $headwayPeakMins–$headwayOffPeakMins mins';

  TransitRouteItem reversed() {
    if (stops.isEmpty) return this;
    final total = stops.last.travelMins > 0 ? stops.last.travelMins : durationMins;
    final revStops = stops.reversed
        .map(
          (s) => TransitStopPoint(
            name: s.name,
            lat: s.lat,
            lon: s.lon,
            travelMins: max(0, total - s.travelMins),
            irCode: s.irCode,
          ),
        )
        .toList();
    return TransitRouteItem(
      id: id,
      routeId: '${routeId}_rev',
      mode: mode,
      code: code,
      routeName: '$destination ➔ $origin',
      operatorName: operatorName,
      origin: destination,
      destination: origin,
      headwayPeakMins: headwayPeakMins,
      headwayOffPeakMins: headwayOffPeakMins,
      firstService: firstService,
      lastService: lastService,
      fareMin: fareMin,
      fareMax: fareMax,
      distanceKm: distanceKm,
      durationMins: durationMins,
      notes: notes,
      stops: revStops,
      departures: departures,
      dailyTripsCount: dailyTripsCount,
    );
  }
}

class RailCorridor {
  final int id;
  final String routeId;
  final String code;
  final String routeName;
  final String operatorName;
  final int headwayPeakMins;
  final int headwayOffPeakMins;
  final String firstService;
  final String lastService;
  final int fareMin;
  final int fareMax;
  final List<RailDirection> directions;

  const RailCorridor({
    required this.id,
    required this.routeId,
    required this.code,
    required this.routeName,
    required this.operatorName,
    required this.headwayPeakMins,
    required this.headwayOffPeakMins,
    required this.firstService,
    required this.lastService,
    required this.fareMin,
    required this.fareMax,
    required this.directions,
  });
}

class RailDirection {
  final String direction;
  final String origin;
  final String destination;
  final int tripsCount;
  final String firstService;
  final String lastService;
  final int durationMins;
  final double distanceKm;
  final List<String> departures;
  final List<TransitStopPoint> stops;

  const RailDirection({
    required this.direction,
    required this.origin,
    required this.destination,
    required this.tripsCount,
    required this.firstService,
    required this.lastService,
    required this.durationMins,
    required this.distanceKm,
    required this.departures,
    required this.stops,
  });

  TransitRouteItem toTransitRouteItem(RailCorridor corridor) {
    return TransitRouteItem(
      id: corridor.id,
      routeId: '${corridor.routeId}_d$direction',
      mode: TransitMode.train,
      code: corridor.code,
      routeName: '$origin ➔ $destination',
      operatorName: corridor.operatorName,
      origin: origin,
      destination: destination,
      headwayPeakMins: corridor.headwayPeakMins,
      headwayOffPeakMins: corridor.headwayOffPeakMins,
      firstService: firstService,
      lastService: lastService,
      fareMin: corridor.fareMin,
      fareMax: corridor.fareMax,
      distanceKm: distanceKm,
      durationMins: durationMins,
      notes: '${corridor.routeName} • $tripsCount daily suburban EMU services',
      stops: stops,
      departures: departures,
      dailyTripsCount: tripsCount,
    );
  }
}

class BreakJourneyLeg {
  final TransitMode mode;
  final String badge;
  final String routeTitle;
  final String fromStop;
  final String toStop;
  final int etaMins;
  final int fareInr;
  final double distanceKm;
  final String timingText;
  final int? busRouteId;
  final String? busType;
  final TransitRouteItem? detailRoute;
  final MetroPlan? metroPlan;
  final LatLng? fromCoord;
  final LatLng? toCoord;
  final List<String> stops;

  const BreakJourneyLeg({
    required this.mode,
    required this.badge,
    required this.routeTitle,
    required this.fromStop,
    required this.toStop,
    required this.etaMins,
    required this.fareInr,
    required this.distanceKm,
    required this.timingText,
    this.busRouteId,
    this.busType,
    this.detailRoute,
    this.metroPlan,
    this.fromCoord,
    this.toCoord,
    this.stops = const [],
  });
}

class BreakJourneyOption {
  final String summaryTag;
  final List<BreakJourneyLeg> legs;
  final int totalEtaMins;
  final int totalFareInr;
  final double totalDistanceKm;
  final int transferWaitMins;
  final bool usesTrain;

  const BreakJourneyOption({
    required this.summaryTag,
    required this.legs,
    required this.totalEtaMins,
    required this.totalFareInr,
    required this.totalDistanceKm,
    required this.transferWaitMins,
    required this.usesTrain,
  });

  String get modeChainLabel => legs.map((l) => transitModeLabel(l.mode)).join(' ➔ ');
}

class _LegMatch {
  final TransitMode mode;
  final String badge;
  final String routeTitle;
  final String fromStop;
  final String toStop;
  final String toKey;
  final String fromKey;
  final LatLng? fromCoord;
  final LatLng? toCoord;
  final int rideMins;
  final int waitMins;
  final int fareInr;
  final double distanceKm;
  final String timingText;
  final int? busRouteId;
  final String? busType;
  final TransitRouteItem? detailRoute;
  final MetroPlan? metroPlan;
  final List<String> stops;

  const _LegMatch({
    required this.mode,
    required this.badge,
    required this.routeTitle,
    required this.fromStop,
    required this.toStop,
    required this.fromKey,
    required this.toKey,
    this.fromCoord,
    this.toCoord,
    required this.rideMins,
    required this.waitMins,
    required this.fareInr,
    required this.distanceKm,
    required this.timingText,
    this.busRouteId,
    this.busType,
    this.detailRoute,
    this.metroPlan,
    this.stops = const [],
  });

  BreakJourneyLeg toLeg() => BreakJourneyLeg(
        mode: mode,
        badge: badge,
        routeTitle: routeTitle,
        fromStop: fromStop,
        toStop: toStop,
        etaMins: rideMins,
        fareInr: fareInr,
        distanceKm: distanceKm,
        timingText: timingText,
        busRouteId: busRouteId,
        busType: busType,
        detailRoute: detailRoute,
        metroPlan: metroPlan,
        fromCoord: fromCoord,
        toCoord: toCoord,
        stops: stops,
      );
}

class _RailStationRef {
  final int corridorIdx;
  final int dirIdx;
  final int stopIdx;
  final String name;
  final String key;
  final LatLng coord;

  const _RailStationRef({
    required this.corridorIdx,
    required this.dirIdx,
    required this.stopIdx,
    required this.name,
    required this.key,
    required this.coord,
  });
}

class MultiTransitService extends ChangeNotifier {
  static final MultiTransitService _instance = MultiTransitService._internal();
  factory MultiTransitService() => _instance;
  MultiTransitService._internal();

  static const String _prefAutoGzKey = 'ota_auto_routes_gz_v1';
  static const String _prefAutoVersionKey = 'ota_auto_version';

  bool _isInitialized = false;
  String _autoVersion = '2.4.0';

  final List<TransitRouteItem> _autoRoutes = [];
  final List<TransitRouteItem> _ferryRoutes = [];
  final List<RailCorridor> _railCorridors = [];

  final List<String> _autoStopNames = [];
  final List<String> _ferryStopNames = [];
  final Map<String, List<_RailStationRef>> _railByStopKey = {};
  final List<_RailStationRef> _allRailStationRefs = [];

  bool get isInitialized => _isInitialized;
  String get autoVersion => _autoVersion;
  int get totalAutoRoutesCount => _autoRoutes.length;
  List<TransitRouteItem> get allAutoRoutes => _autoRoutes;
  List<TransitRouteItem> get allFerryRoutes => _ferryRoutes;
  List<RailCorridor> get allRailCorridors => _railCorridors;
  List<String> get autoStopNames => _autoStopNames;
  List<String> get ferryStopNames => _ferryStopNames;

  Future<void> init() async {
    if (_isInitialized) return;
    String? cachedAutoJson;
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoGz = prefs.getString(_prefAutoGzKey);
      if (autoGz != null && autoGz.isNotEmpty) {
        final decodedJson = utf8.decode(gzip.decode(base64.decode(autoGz)));
        final parsed = json.decode(decodedJson);
        if (parsed is List && parsed.isNotEmpty) {
          cachedAutoJson = decodedJson;
          _autoVersion = prefs.getString(_prefAutoVersionKey) ?? _autoVersion;
        }
      }
    } catch (_) {
      // Fall back to bundled auto asset
    }

    try {
      final results = await Future.wait([
        cachedAutoJson != null ? Future.value(cachedAutoJson) : rootBundle.loadString('assets/kolkata_auto_routes.json'),
        rootBundle.loadString('assets/kolkata_ferry_routes.json'),
        rootBundle.loadString('assets/kolkata_rail_routes.json'),
      ]);
      loadFromJsonStrings(
        autoJson: results[0],
        ferryJson: results[1],
        railJson: results[2],
      );
    } catch (_) {
      _isInitialized = true;
    }
  }

  /// Applies freshly synced OTA auto routes in memory and persists compressed on device.
  Future<bool> applyOtaAutoRoutes({
    required String version,
    required String autoJson,
  }) async {
    try {
      final decoded = json.decode(autoJson);
      if (decoded is! List || decoded.isEmpty) {
        return false;
      }
      loadFromJsonStrings(autoJson: autoJson);
      _autoVersion = version;

      final prefs = await SharedPreferences.getInstance();
      final autoGz = base64.encode(gzip.encode(utf8.encode(autoJson)));
      await prefs.setString(_prefAutoGzKey, autoGz);
      await prefs.setString(_prefAutoVersionKey, version);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void loadFromJsonStrings({
    String? autoJson,
    String? ferryJson,
    String? railJson,
  }) {
    if (autoJson != null && autoJson.isNotEmpty) {
      _autoRoutes.clear();
      _autoStopNames.clear();
      final decoded = json.decode(autoJson) as List<dynamic>;
      final stopSet = <String>{};
      for (final item in decoded) {
        final m = item as Map<String, dynamic>;
        final stops = _parseStops(m['stops'] as List? ?? []);
        for (final s in stops) {
          stopSet.add(s.name);
        }
        _autoRoutes.add(
          TransitRouteItem(
            id: (m['id'] as num?)?.toInt() ?? 0,
            routeId: (m['rid'] ?? '').toString(),
            mode: TransitMode.auto,
            code: (m['r'] ?? 'AUTO').toString(),
            routeName: (m['rn'] ?? '').toString(),
            operatorName: 'Kolkata & Suburb Auto Service',
            origin: (m['f'] ?? '').toString(),
            destination: (m['t'] ?? '').toString(),
            headwayPeakMins: (m['hwP'] as num?)?.toInt() ?? 6,
            headwayOffPeakMins: (m['hwO'] as num?)?.toInt() ?? 10,
            firstService: (m['fs'] ?? '06:00').toString(),
            lastService: (m['ls'] ?? '22:30').toString(),
            fareMin: (m['fMin'] as num?)?.toInt() ?? 10,
            fareMax: (m['fMax'] as num?)?.toInt() ?? 15,
            distanceKm: (m['km'] as num?)?.toDouble() ?? 3.0,
            durationMins: (m['dur'] as num?)?.toInt() ?? 12,
            notes: (m['nt'] ?? '').toString(),
            stops: stops,
          ),
        );
      }
      _autoStopNames.addAll(stopSet.toList()..sort());
    }

    if (ferryJson != null && ferryJson.isNotEmpty) {
      _ferryRoutes.clear();
      _ferryStopNames.clear();
      final decoded = json.decode(ferryJson) as List<dynamic>;
      final stopSet = <String>{};
      for (final item in decoded) {
        final m = item as Map<String, dynamic>;
        final stops = _parseStops(m['stops'] as List? ?? []);
        for (final s in stops) {
          stopSet.add(s.name);
        }
        _ferryRoutes.add(
          TransitRouteItem(
            id: (m['id'] as num?)?.toInt() ?? 0,
            routeId: (m['rid'] ?? '').toString(),
            mode: TransitMode.ferry,
            code: (m['r'] ?? 'FERRY').toString(),
            routeName: (m['rn'] ?? '').toString(),
            operatorName: (m['op'] ?? 'WBSTC / Hooghly Ferry').toString(),
            origin: (m['f'] ?? '').toString(),
            destination: (m['t'] ?? '').toString(),
            headwayPeakMins: (m['hwP'] as num?)?.toInt() ?? 15,
            headwayOffPeakMins: (m['hwO'] as num?)?.toInt() ?? 15,
            firstService: (m['fs'] ?? '07:00').toString(),
            lastService: (m['ls'] ?? '20:00').toString(),
            fareMin: (m['fMin'] as num?)?.toInt() ?? 6,
            fareMax: (m['fMax'] as num?)?.toInt() ?? 10,
            distanceKm: (m['km'] as num?)?.toDouble() ?? 1.5,
            durationMins: (m['dur'] as num?)?.toInt() ?? 10,
            notes: (m['nt'] ?? '').toString(),
            stops: stops,
          ),
        );
      }
      _ferryStopNames.addAll(stopSet.toList()..sort());
    }

    if (railJson != null && railJson.isNotEmpty) {
      _railCorridors.clear();
      _railByStopKey.clear();
      _allRailStationRefs.clear();
      final decoded = json.decode(railJson) as List<dynamic>;
      for (int cIdx = 0; cIdx < decoded.length; cIdx++) {
        final m = decoded[cIdx] as Map<String, dynamic>;
        final rawDirs = m['dirs'] as List? ?? [];
        final dirs = <RailDirection>[];
        for (int dIdx = 0; dIdx < rawDirs.length; dIdx++) {
          final dm = rawDirs[dIdx] as Map<String, dynamic>;
          final stops = _parseStops(dm['stops'] as List? ?? []);
          final deps = (dm['deps'] as List? ?? []).map((e) => e.toString()).toList();
          dirs.add(
            RailDirection(
              direction: (dm['d'] ?? '$dIdx').toString(),
              origin: (dm['f'] ?? '').toString(),
              destination: (dm['t'] ?? '').toString(),
              tripsCount: (dm['cnt'] as num?)?.toInt() ?? deps.length,
              firstService: (dm['fs'] ?? '04:30').toString(),
              lastService: (dm['ls'] ?? '23:00').toString(),
              durationMins: (dm['dur'] as num?)?.toInt() ?? 45,
              distanceKm: (dm['km'] as num?)?.toDouble() ?? 20.0,
              departures: deps,
              stops: stops,
            ),
          );
          for (int sIdx = 0; sIdx < stops.length; sIdx++) {
            final st = stops[sIdx];
            final ll = st.latLng;
            if (ll == null) continue;
            final key = KolkataGeo.normalizeStopKey(st.name);
            final ref = _RailStationRef(
              corridorIdx: cIdx,
              dirIdx: dIdx,
              stopIdx: sIdx,
              name: st.name,
              key: key,
              coord: ll,
            );
            _railByStopKey.putIfAbsent(key, () => []).add(ref);
            _allRailStationRefs.add(ref);
          }
        }
        _railCorridors.add(
          RailCorridor(
            id: (m['id'] as num?)?.toInt() ?? 0,
            routeId: (m['rid'] ?? '').toString(),
            code: (m['r'] ?? 'EMU').toString(),
            routeName: (m['rn'] ?? '').toString(),
            operatorName: (m['op'] ?? 'Eastern / South Eastern Railway').toString(),
            headwayPeakMins: (m['hwP'] as num?)?.toInt() ?? 20,
            headwayOffPeakMins: (m['hwO'] as num?)?.toInt() ?? 35,
            firstService: (m['fs'] ?? '04:30').toString(),
            lastService: (m['ls'] ?? '23:00').toString(),
            fareMin: (m['fMin'] as num?)?.toInt() ?? 5,
            fareMax: (m['fMax'] as num?)?.toInt() ?? 25,
            directions: dirs,
          ),
        );
      }
    }

    // Register unique Auto, Ferry, and Rail stations for Break Journey autocomplete
    final extras = <BusStopItem>[];
    for (final s in _ferryStopNames) {
      extras.add(BusStopItem(name: s, subtitle: 'Hooghly Ferry Ghat', routesCount: 1));
    }
    for (final r in _allRailStationRefs) {
      extras.add(BusStopItem(name: r.name, subtitle: 'Suburban Railway Station', routesCount: 1));
    }
    for (final s in _autoStopNames) {
      extras.add(BusStopItem(name: s, subtitle: 'Share Auto Stand', routesCount: 0));
    }
    KolkataStops.addExtraStops(extras);

    _isInitialized = true;
  }

  static List<TransitStopPoint> _parseStops(List<dynamic> raw) {
    return raw.map((e) {
      final sm = e as Map<String, dynamic>;
      return TransitStopPoint(
        name: (sm['n'] ?? '').toString(),
        lat: (sm['lat'] as num?)?.toDouble(),
        lon: (sm['lon'] as num?)?.toDouble(),
        travelMins: (sm['m'] as num?)?.toInt() ?? 0,
        irCode: (sm['c'] ?? '').toString(),
      );
    }).toList();
  }

  // --------------------------------------------------------------------------
  // STOP SUGGESTIONS & OFFLINE AUTO / FERRY SEARCH
  // --------------------------------------------------------------------------
  List<String> searchAutoStops(String query, {int limit = 15}) =>
      _filterNames(_autoStopNames, query, limit: limit);

  List<String> searchFerryStops(String query, {int limit = 15}) =>
      _filterNames(_ferryStopNames, query, limit: limit);

  static List<String> _filterNames(List<String> source, String query, {int limit = 15}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return source.take(limit).toList();
    final starts = <String>[];
    final contains = <String>[];
    for (final s in source) {
      final low = s.toLowerCase();
      if (low.startsWith(q)) {
        starts.add(s);
      } else if (low.contains(q)) {
        contains.add(s);
      }
    }
    return [...starts, ...contains].take(limit).toList();
  }

  List<TransitRouteItem> searchAutoRoutes(String from, String to, {int limit = 60}) =>
      _searchPointRoutes(_autoRoutes, from, to, limit: limit);

  List<TransitRouteItem> searchFerryRoutes(String from, String to, {int limit = 30}) =>
      _searchPointRoutes(_ferryRoutes, from, to, limit: limit);

  List<TransitRouteItem> _searchPointRoutes(
    List<TransitRouteItem> pool,
    String from,
    String to, {
    int limit = 60,
  }) {
    final f = from.trim();
    final t = to.trim();
    if (f.isEmpty && t.isEmpty) return pool.take(limit).toList();

    final fTerms = f.isNotEmpty ? BusDataService.expandStopTermsPublic(f) : <String>[];
    final tTerms = t.isNotEmpty ? BusDataService.expandStopTermsPublic(t) : <String>[];

    final matches = <TransitRouteItem>[];
    final seen = <String>{};

    for (final route in pool) {
      if (fTerms.isNotEmpty && tTerms.isEmpty) {
        final codeUp = route.code.toUpperCase();
        final matchesCode = codeUp.contains(f.toUpperCase());
        final matchesStop = route.stops.any((s) => _stopMatchesTerms(s.name, fTerms));
        if (matchesCode || matchesStop) {
          if (seen.add(route.routeId)) matches.add(route);
        }
      } else {
        // Bidirectional check (Kolkata shared autos & ferries operate both ways)
        final fwd = _findDirectedPair(route.stops, fTerms, tTerms);
        if (fwd != null) {
          if (seen.add('${route.routeId}_fwd')) matches.add(route);
        } else {
          final revRoute = route.reversed();
          final rev = _findDirectedPair(revRoute.stops, fTerms, tTerms);
          if (rev != null && seen.add('${route.routeId}_rev')) {
            matches.add(revRoute);
          }
        }
      }
      if (matches.length >= limit) break;
    }

    matches.sort((a, b) => a.durationMins.compareTo(b.durationMins));
    return matches;
  }

  static (int, int)? _findDirectedPair(
    List<TransitStopPoint> stops,
    List<String> fTerms,
    List<String> tTerms,
  ) {
    if (fTerms.isEmpty) {
      for (int i = 0; i < stops.length; i++) {
        if (_stopMatchesTerms(stops[i].name, tTerms)) return (0, i);
      }
      return null;
    }
    for (int i = 0; i < stops.length; i++) {
      if (!_stopMatchesTerms(stops[i].name, fTerms)) continue;
      if (tTerms.isEmpty) return (i, stops.length - 1);
      for (int j = i + 1; j < stops.length; j++) {
        if (_stopMatchesTerms(stops[j].name, tTerms)) {
          return (i, j);
        }
      }
    }
    return null;
  }

  static bool _stopMatchesTerms(String stopName, List<String> terms) {
    final low = stopName.toLowerCase();
    for (final term in terms) {
      if (low.contains(term)) return true;
    }
    return false;
  }

  // --------------------------------------------------------------------------
  // RAIL TIMETABLE & FARE HELPERS (ONLY USED FOR BREAK JOURNEY SUGGESTIONS)
  // --------------------------------------------------------------------------
  static int calculateSuburbanRailFare(double km) {
    if (km <= 20) return 5;
    if (km <= 41) return 10;
    if (km <= 69) return 15;
    if (km <= 95) return 20;
    return 25;
  }

  static int? _parseHhMm(String hhmm) {
    final p = hhmm.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static String formatMins12h(int minsOfDay) {
    final m = ((minsOfDay % 1440) + 1440) % 1440;
    final h24 = m ~/ 60;
    final min = m % 60;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '${h12.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} $ampm';
  }

  /// Returns upcoming scheduled departure strings & wait minutes at a given stop offset
  static ({int waitMins, List<String> nextFormatted}) upcomingDeparturesAtOffset(
    List<String> originDeps,
    int stopOffsetMins,
    int headwayFallbackMins,
    DateTime now, {
    int count = 5,
  }) {
    if (originDeps.isEmpty) {
      return (waitMins: (headwayFallbackMins / 2).round().clamp(4, 15), nextFormatted: const []);
    }
    final nowMins = now.hour * 60 + now.minute;
    final adjusted = <int>[];
    for (final d in originDeps) {
      final base = _parseHhMm(d);
      if (base != null) adjusted.add((base + stopOffsetMins) % 1440);
    }
    adjusted.sort();

    final upcoming = <int>[];
    for (final dep in adjusted) {
      if (dep >= nowMins) upcoming.add(dep);
    }
    int wait;
    if (upcoming.isNotEmpty) {
      wait = (upcoming.first - nowMins).clamp(2, 25);
    } else if (adjusted.isNotEmpty) {
      // Next day early morning train wait capped cleanly for route ranking
      wait = (headwayFallbackMins / 2).round().clamp(5, 18);
      upcoming.addAll(adjusted.take(count));
    } else {
      wait = (headwayFallbackMins / 2).round().clamp(5, 18);
    }

    return (
      waitMins: wait,
      nextFormatted: upcoming.take(count).map(formatMins12h).toList(),
    );
  }

  // --------------------------------------------------------------------------
  // MULTIMODAL BREAK JOURNEY ENGINE (ALWAYS SORTED BY SHORTEST ETA)
  // Uses Train + Bus + Auto + Ferry + Metro
  // --------------------------------------------------------------------------
  List<BreakJourneyOption> suggestBreakJourneys(
    String from,
    String to, {
    int limit = 16,
    DateTime? atTime,
  }) {
    final cleanFrom = from.trim();
    final cleanTo = to.trim();
    if (cleanFrom.isEmpty || cleanTo.isEmpty) return [];
    final now = atTime ?? DateTime.now();

    final fromTerms = BusDataService.expandStopTermsPublic(cleanFrom);
    final toTerms = BusDataService.expandStopTermsPublic(cleanTo);
    if (fromTerms.isEmpty || toTerms.isEmpty) return [];

    final fromCoord = _resolveAnchorCoord(cleanFrom, fromTerms);
    final toCoord = _resolveAnchorCoord(cleanTo, toTerms);

    // Build start-reachable legs (Leg 1 candidates) & end-reachable legs (Leg 2 candidates)
    final leg1List = _collectOriginLegs(cleanFrom, fromTerms, fromCoord, now);
    final leg2List = _collectDestLegs(cleanTo, toTerms, toCoord, now);

    final candidates = <BreakJourneyOption>[];
    final seenSignatures = <String>{};

    void addCandidate(BreakJourneyOption opt) {
      // Discard absurd self-loops
      if (opt.legs.length >= 2) {
        final firstStart = KolkataGeo.normalizeStopKey(opt.legs.first.fromStop);
        final lastEnd = KolkataGeo.normalizeStopKey(opt.legs.last.toStop);
        if (firstStart.isNotEmpty && firstStart == lastEnd) return;
      }
      final sig = opt.legs
          .map((l) => '${l.mode.name}:${l.badge}:${KolkataGeo.normalizeStopKey(l.toStop)}')
          .join('>');
      if (seenSignatures.contains(sig)) return;
      seenSignatures.add(sig);
      candidates.add(opt);
    }

    // A) Direct Train routes ONLY in Break Journey Suggestions (when origin & dest have suburban stations nearby)
    for (final leg in _findDirectTrainOptions(cleanFrom, fromTerms, fromCoord, cleanTo, toTerms, toCoord, now)) {
      addCandidate(leg);
    }

    // B) 2-Leg Multimodal Connections (Leg1 -> Hub -> Leg2) across Train, Bus, Auto, Ferry, Metro
    // Index leg2 by normalized start key for instant match
    final leg2ByKey = <String, List<_LegMatch>>{};
    for (final l2 in leg2List) {
      leg2ByKey.putIfAbsent(l2.fromKey, () => []).add(l2);
    }

    for (final l1 in leg1List) {
      // Prevent trivial loop back to origin
      if (l1.toKey == l1.fromKey) continue;

      final matchingL2 = <_LegMatch>[];
      if (leg2ByKey.containsKey(l1.toKey)) {
        matchingL2.addAll(leg2ByKey[l1.toKey]!);
      } else if (l1.toCoord != null) {
        // Geographic walk connection (< 0.75 km)
        for (final l2 in leg2List) {
          if (l2.fromCoord == null) continue;
          final walk = KolkataGeo.haversineKm(l1.toCoord!, l2.fromCoord!);
          if (walk <= 0.75) {
            matchingL2.add(l2);
          }
        }
      }

      for (final l2 in matchingL2) {
        // Must actually switch route or mode
        if (l1.mode == l2.mode && l1.badge == l2.badge) continue;
        if (l2.toKey == l1.fromKey || l2.toKey == l1.toKey) continue;

        final walkKm = (l1.toCoord != null && l2.fromCoord != null)
            ? KolkataGeo.haversineKm(l1.toCoord!, l2.fromCoord!)
            : 0.1;
        final transferPenalty = 4 + (walkKm * 10).round().clamp(0, 10) + (l2.waitMins ~/ 2).clamp(2, 10);
        final totalEta = l1.waitMins + l1.rideMins + transferPenalty + l2.rideMins;
        final totalFare = l1.fareInr + l2.fareInr;
        final totalDist = double.parse((l1.distanceKm + walkKm + l2.distanceKm).toStringAsFixed(1));
        final usesTrain = l1.mode == TransitMode.train || l2.mode == TransitMode.train;

        addCandidate(
          BreakJourneyOption(
            summaryTag: usesTrain ? 'TRAIN + ${transitModeLabel(l1.mode == TransitMode.train ? l2.mode : l1.mode)} BREAK' : '${transitModeLabel(l1.mode)} ➔ ${transitModeLabel(l2.mode)}',
            legs: [l1.toLeg(), l2.toLeg()],
            totalEtaMins: totalEta,
            totalFareInr: totalFare,
            totalDistanceKm: totalDist,
            transferWaitMins: transferPenalty,
            usesTrain: usesTrain,
          ),
        );
      }
    }

    // C) 3-Leg Train-Bridged Journeys: (Auto/Bus/Ferry/Metro -> RailStation1) -> TRAIN -> (RailStation2 -> Auto/Bus/Ferry/Metro)
    // Pick best Leg1 ending at/near a Rail station & best Leg2 starting at/near a Rail station
    final accessToRail = <({ _LegMatch leg, _RailStationRef st, double walkKm })>[];
    for (final l1 in leg1List) {
      if (l1.mode == TransitMode.train) continue;
      final refs = _matchRailStationsForHub(l1.toKey, l1.toCoord, maxWalkKm: 0.85);
      for (final r in refs.take(2)) {
        accessToRail.add((leg: l1, st: r.ref, walkKm: r.walkKm));
      }
    }

    final egressFromRail = <({ _LegMatch leg, _RailStationRef st, double walkKm })>[];
    for (final l2 in leg2List) {
      if (l2.mode == TransitMode.train) continue;
      final refs = _matchRailStationsForHub(l2.fromKey, l2.fromCoord, maxWalkKm: 0.85);
      for (final r in refs.take(2)) {
        egressFromRail.add((leg: l2, st: r.ref, walkKm: r.walkKm));
      }
    }

    // Group egress by (corridorIdx, dirIdx) for O(1) lookup
    final egressByCorridorDir = <(int, int), List<({ _LegMatch leg, _RailStationRef st, double walkKm })>>{};
    for (final eg in egressFromRail) {
      egressByCorridorDir.putIfAbsent((eg.st.corridorIdx, eg.st.dirIdx), () => []).add(eg);
    }

    int threeLegCount = 0;
    for (final ac in accessToRail) {
      if (threeLegCount > 160) break;
      final key = (ac.st.corridorIdx, ac.st.dirIdx);
      final egs = egressByCorridorDir[key];
      if (egs == null) continue;

      final corridor = _railCorridors[ac.st.corridorIdx];
      final dir = corridor.directions[ac.st.dirIdx];

      for (final eg in egs) {
        if (ac.st.stopIdx >= eg.st.stopIdx) continue;
        // Require at least 2 stations on train to make switching worthwhile
        if (eg.st.stopIdx - ac.st.stopIdx < 2) continue;
        // Skip backtracking where access endpoint already overlaps egress start
        if (ac.st.key == eg.st.key) continue;

        final trainLeg = _buildTrainLegMatch(corridor, dir, ac.st.stopIdx, eg.st.stopIdx, now);
        final pen1 = 4 + (ac.walkKm * 10).round().clamp(0, 9) + (trainLeg.waitMins ~/ 2).clamp(3, 12);
        final pen2 = 4 + (eg.walkKm * 10).round().clamp(0, 9);
        final totalEta = ac.leg.waitMins + ac.leg.rideMins + pen1 + trainLeg.rideMins + pen2 + eg.leg.rideMins;
        final totalFare = ac.leg.fareInr + trainLeg.fareInr + eg.leg.fareInr;
        final totalDist = double.parse(
          (ac.leg.distanceKm + ac.walkKm + trainLeg.distanceKm + eg.walkKm + eg.leg.distanceKm).toStringAsFixed(1),
        );

        addCandidate(
          BreakJourneyOption(
            summaryTag: 'FASTEST TRAIN + ${transitModeLabel(ac.leg.mode)} + ${transitModeLabel(eg.leg.mode)}',
            legs: [ac.leg.toLeg(), trainLeg.toLeg(), eg.leg.toLeg()],
            totalEtaMins: totalEta,
            totalFareInr: totalFare,
            totalDistanceKm: totalDist,
            transferWaitMins: pen1 + pen2,
            usesTrain: true,
          ),
        );
        threeLegCount++;
      }
    }

    // ALWAYS sort strictly by ETA (shortest travel time first!), then fewer legs, then lower fare
    candidates.sort((a, b) {
      final etaCmp = a.totalEtaMins.compareTo(b.totalEtaMins);
      if (etaCmp != 0) return etaCmp;
      final legCmp = a.legs.length.compareTo(b.legs.length);
      if (legCmp != 0) return legCmp;
      return a.totalFareInr.compareTo(b.totalFareInr);
    });

    return candidates.take(limit).toList();
  }

  LatLng? _resolveAnchorCoord(String rawQuery, List<String> terms) {
    final direct = KolkataGeo.lookupExactCoord(rawQuery);
    if (direct != null) return direct;
    for (final t in terms) {
      final found = KolkataGeo.lookupExactCoord(t);
      if (found != null) return found;
    }
    return null;
  }

  List<({ _RailStationRef ref, double walkKm })> _matchRailStationsForHub(
    String stopKey,
    LatLng? coord, {
    double maxWalkKm = 0.85,
  }) {
    final res = <({ _RailStationRef ref, double walkKm })>[];
    if (_railByStopKey.containsKey(stopKey)) {
      for (final r in _railByStopKey[stopKey]!) {
        res.add((ref: r, walkKm: 0.05));
      }
      return res;
    }
    if (coord == null) return res;
    for (final r in _allRailStationRefs) {
      final d = KolkataGeo.haversineKm(coord, r.coord);
      if (d <= maxWalkKm) {
        res.add((ref: r, walkKm: d));
      }
    }
    res.sort((a, b) => a.walkKm.compareTo(b.walkKm));
    return res;
  }

  List<BreakJourneyOption> _findDirectTrainOptions(
    String from,
    List<String> fromTerms,
    LatLng? fromCoord,
    String to,
    List<String> toTerms,
    LatLng? toCoord,
    DateTime now,
  ) {
    final options = <BreakJourneyOption>[];
    for (final corridor in _railCorridors) {
      for (final dir in corridor.directions) {
        int bIdx = -1;
        for (int i = 0; i < dir.stops.length; i++) {
          if (_stopOrProximityMatches(dir.stops[i].name, dir.stops[i].latLng, fromTerms, fromCoord, maxKm: 0.9)) {
            bIdx = i;
            break;
          }
        }
        if (bIdx == -1) continue;
        int aIdx = -1;
        for (int j = bIdx + 1; j < dir.stops.length; j++) {
          if (_stopOrProximityMatches(dir.stops[j].name, dir.stops[j].latLng, toTerms, toCoord, maxKm: 0.9)) {
            aIdx = j;
            break;
          }
        }
        if (aIdx == -1) continue;

        final leg = _buildTrainLegMatch(corridor, dir, bIdx, aIdx, now);
        options.add(
          BreakJourneyOption(
            summaryTag: 'SUBURBAN LOCAL TRAIN (SUGGESTED)',
            legs: [leg.toLeg()],
            totalEtaMins: leg.waitMins + leg.rideMins,
            totalFareInr: leg.fareInr,
            totalDistanceKm: leg.distanceKm,
            transferWaitMins: leg.waitMins,
            usesTrain: true,
          ),
        );
      }
    }
    return options;
  }

  _LegMatch _buildTrainLegMatch(
    RailCorridor corridor,
    RailDirection dir,
    int boardIdx,
    int alightIdx,
    DateTime now,
  ) {
    final sFrom = dir.stops[boardIdx];
    final sTo = dir.stops[alightIdx];
    final rideMins = max(4, sTo.travelMins - sFrom.travelMins);
    double km = 0;
    for (int k = boardIdx; k < alightIdx; k++) {
      final a = dir.stops[k].latLng;
      final b = dir.stops[k + 1].latLng;
      if (a != null && b != null) km += KolkataGeo.haversineKm(a, b);
    }
    if (km < 0.5) km = max(1.5, rideMins * 0.6);
    km = double.parse(km.toStringAsFixed(1));
    final fare = calculateSuburbanRailFare(km);
    final deps = upcomingDeparturesAtOffset(dir.departures, sFrom.travelMins, corridor.headwayPeakMins, now);
    final nextText = deps.nextFormatted.isNotEmpty
        ? 'Next ${deps.nextFormatted.first} • Every ${corridor.headwayPeakMins}m'
        : '${dir.firstService}–${dir.lastService} • Every ${corridor.headwayPeakMins}m';

    return _LegMatch(
      mode: TransitMode.train,
      badge: corridor.code,
      routeTitle: '${dir.origin} ➔ ${dir.destination} Local',
      fromStop: sFrom.name,
      toStop: sTo.name,
      fromKey: KolkataGeo.normalizeStopKey(sFrom.name),
      toKey: KolkataGeo.normalizeStopKey(sTo.name),
      fromCoord: sFrom.latLng,
      toCoord: sTo.latLng,
      rideMins: rideMins,
      waitMins: deps.waitMins,
      fareInr: fare,
      distanceKm: km,
      timingText: nextText,
      detailRoute: dir.toTransitRouteItem(corridor),
      stops: dir.stops.sublist(boardIdx, alightIdx + 1).map((s) => s.name).toList(),
    );
  }

  static bool _stopOrProximityMatches(
    String stopName,
    LatLng? coord,
    List<String> terms,
    LatLng? anchorCoord, {
    double maxKm = 0.75,
  }) {
    if (_stopMatchesTerms(stopName, terms)) return true;
    if (coord != null && anchorCoord != null) {
      return KolkataGeo.haversineKm(coord, anchorCoord) <= maxKm;
    }
    return false;
  }

  /// Collects fast outgoing legs from `From` across Train, Auto, Ferry, Metro, and Bus
  List<_LegMatch> _collectOriginLegs(
    String from,
    List<String> fromTerms,
    LatLng? fromCoord,
    DateTime now,
  ) {
    final legs = <_LegMatch>[];

    // 1. Auto legs from origin (capped to best per destination stop)
    final bestAutoByDest = <String, _LegMatch>{};
    for (final route in _autoRoutes) {
      for (final variant in [route, route.reversed()]) {
        final fIdx = variant.stops.indexWhere(
          (s) => _stopOrProximityMatches(s.name, s.latLng, fromTerms, fromCoord, maxKm: 0.65),
        );
        if (fIdx == -1 || fIdx >= variant.stops.length - 1) continue;
        final sFrom = variant.stops[fIdx];
        for (int j = fIdx + 1; j < variant.stops.length; j++) {
          final sTo = variant.stops[j];
          final km = _segmentKm(sFrom.latLng, sTo.latLng, (j - fIdx) * 1.1);
          final mins = max(4, (sTo.travelMins - sFrom.travelMins).abs()).clamp(4, 45);
          final fare = km <= 2.5 ? 10 : km <= 5.5 ? 15 : 20;
          final toKey = KolkataGeo.normalizeStopKey(sTo.name);
          final cand = _LegMatch(
            mode: TransitMode.auto,
            badge: variant.code,
            routeTitle: variant.routeName,
            fromStop: sFrom.name,
            toStop: sTo.name,
            fromKey: KolkataGeo.normalizeStopKey(sFrom.name),
            toKey: toKey,
            fromCoord: sFrom.latLng,
            toCoord: sTo.latLng,
            rideMins: mins,
            waitMins: 3,
            fareInr: fare,
            distanceKm: km,
            timingText: 'Every ${variant.headwayPeakMins}–${variant.headwayOffPeakMins} mins',
            detailRoute: variant,
            stops: variant.stops.sublist(fIdx, j + 1).map((s) => s.name).toList(),
          );
          if (!bestAutoByDest.containsKey(toKey) || cand.rideMins < bestAutoByDest[toKey]!.rideMins) {
            bestAutoByDest[toKey] = cand;
          }
        }
      }
    }
    legs.addAll(bestAutoByDest.values);

    // 2. Ferry legs from origin
    for (final route in _ferryRoutes) {
      for (final variant in [route, route.reversed()]) {
        final fIdx = variant.stops.indexWhere(
          (s) => _stopOrProximityMatches(s.name, s.latLng, fromTerms, fromCoord, maxKm: 0.8),
        );
        if (fIdx == -1 || fIdx >= variant.stops.length - 1) continue;
        final sFrom = variant.stops[fIdx];
        for (int j = fIdx + 1; j < variant.stops.length; j++) {
          final sTo = variant.stops[j];
          final km = _segmentKm(sFrom.latLng, sTo.latLng, 1.5);
          final mins = max(5, (sTo.travelMins - sFrom.travelMins).abs());
          legs.add(
            _LegMatch(
              mode: TransitMode.ferry,
              badge: 'FERRY',
              routeTitle: variant.routeName,
              fromStop: sFrom.name,
              toStop: sTo.name,
              fromKey: KolkataGeo.normalizeStopKey(sFrom.name),
              toKey: KolkataGeo.normalizeStopKey(sTo.name),
              fromCoord: sFrom.latLng,
              toCoord: sTo.latLng,
              rideMins: mins,
              waitMins: (variant.headwayPeakMins / 2).round().clamp(4, 15),
              fareInr: variant.fareMin,
              distanceKm: km,
              timingText: '${variant.firstService}–${variant.lastService} • Every ${variant.headwayPeakMins}m',
              detailRoute: variant,
              stops: variant.stops.sublist(fIdx, j + 1).map((s) => s.name).toList(),
            ),
          );
        }
      }
    }

    // 3. Train legs starting near origin
    for (final corridor in _railCorridors) {
      for (final dir in corridor.directions) {
        final bIdx = dir.stops.indexWhere(
          (s) => _stopOrProximityMatches(s.name, s.latLng, fromTerms, fromCoord, maxKm: 0.85),
        );
        if (bIdx == -1 || bIdx >= dir.stops.length - 1) continue;
        for (int j = bIdx + 1; j < dir.stops.length; j++) {
          legs.add(_buildTrainLegMatch(corridor, dir, bIdx, j, now));
        }
      }
    }

    // 4. Metro legs from origin
    legs.addAll(_collectMetroLegsFrom(fromTerms, fromCoord));

    // 5. Bus legs from origin (fastest per destination stop to stay lean)
    final bestBusByDest = <String, _LegMatch>{};
    for (final rec in BusDataService().rawRecords) {
      final fIdx = BusDataService.findStopIndexPublic(rec.stopsLower, fromTerms);
      if (fIdx == -1 || fIdx >= rec.stops.length - 1) continue;
      final sFromName = rec.stops[fIdx];
      final sFromCoord = KolkataGeo.lookupExactCoord(sFromName);
      for (int j = fIdx + 1; j < rec.stops.length; j++) {
        final sToName = rec.stops[j];
        final toKey = KolkataGeo.normalizeStopKey(sToName);
        if (toKey.isEmpty) continue;
        final sToCoord = KolkataGeo.lookupExactCoord(sToName);
        final stopDiff = j - fIdx;
        final km = _segmentKm(sFromCoord, sToCoord, stopDiff * 1.15);
        final mins = sFromCoord != null && sToCoord != null
            ? max(5, (km / 17.5 * 60).round())
            : max(5, (stopDiff * 3.0).round());
        final fare = BusDataService.calculateBusFare(rec.busType, stopDiff);
        final cand = _LegMatch(
          mode: TransitMode.bus,
          badge: rec.routeNo,
          routeTitle: '${rec.origin} ➔ ${rec.destination}',
          fromStop: sFromName,
          toStop: sToName,
          fromKey: KolkataGeo.normalizeStopKey(sFromName),
          toKey: toKey,
          fromCoord: sFromCoord,
          toCoord: sToCoord,
          rideMins: mins,
          waitMins: 5,
          fareInr: fare,
          distanceKm: km,
          timingText: 'Runs daily • Every 8–12 mins',
          busRouteId: rec.id,
          busType: rec.busType,
          stops: rec.stops.sublist(fIdx, j + 1),
        );
        if (!bestBusByDest.containsKey(toKey) || cand.rideMins < bestBusByDest[toKey]!.rideMins) {
          bestBusByDest[toKey] = cand;
        }
      }
    }
    legs.addAll(bestBusByDest.values);
    return legs;
  }

  /// Collects fast incoming legs arriving at `To` across Train, Auto, Ferry, Metro, and Bus
  List<_LegMatch> _collectDestLegs(
    String to,
    List<String> toTerms,
    LatLng? toCoord,
    DateTime now,
  ) {
    final legs = <_LegMatch>[];

    // 1. Auto legs ending at destination
    final bestAutoByStart = <String, _LegMatch>{};
    for (final route in _autoRoutes) {
      for (final variant in [route, route.reversed()]) {
        final tIdx = variant.stops.lastIndexWhere(
          (s) => _stopOrProximityMatches(s.name, s.latLng, toTerms, toCoord, maxKm: 0.65),
        );
        if (tIdx <= 0) continue;
        final sTo = variant.stops[tIdx];
        for (int i = 0; i < tIdx; i++) {
          final sFrom = variant.stops[i];
          final km = _segmentKm(sFrom.latLng, sTo.latLng, (tIdx - i) * 1.1);
          final mins = max(4, (sTo.travelMins - sFrom.travelMins).abs()).clamp(4, 45);
          final fare = km <= 2.5 ? 10 : km <= 5.5 ? 15 : 20;
          final fromKey = KolkataGeo.normalizeStopKey(sFrom.name);
          final cand = _LegMatch(
            mode: TransitMode.auto,
            badge: variant.code,
            routeTitle: variant.routeName,
            fromStop: sFrom.name,
            toStop: sTo.name,
            fromKey: fromKey,
            toKey: KolkataGeo.normalizeStopKey(sTo.name),
            fromCoord: sFrom.latLng,
            toCoord: sTo.latLng,
            rideMins: mins,
            waitMins: 3,
            fareInr: fare,
            distanceKm: km,
            timingText: 'Every ${variant.headwayPeakMins}–${variant.headwayOffPeakMins} mins',
            detailRoute: variant,
            stops: variant.stops.sublist(i, tIdx + 1).map((s) => s.name).toList(),
          );
          if (!bestAutoByStart.containsKey(fromKey) || cand.rideMins < bestAutoByStart[fromKey]!.rideMins) {
            bestAutoByStart[fromKey] = cand;
          }
        }
      }
    }
    legs.addAll(bestAutoByStart.values);

    // 2. Ferry legs ending at destination
    for (final route in _ferryRoutes) {
      for (final variant in [route, route.reversed()]) {
        final tIdx = variant.stops.lastIndexWhere(
          (s) => _stopOrProximityMatches(s.name, s.latLng, toTerms, toCoord, maxKm: 0.8),
        );
        if (tIdx <= 0) continue;
        final sTo = variant.stops[tIdx];
        for (int i = 0; i < tIdx; i++) {
          final sFrom = variant.stops[i];
          final km = _segmentKm(sFrom.latLng, sTo.latLng, 1.5);
          final mins = max(5, (sTo.travelMins - sFrom.travelMins).abs());
          legs.add(
            _LegMatch(
              mode: TransitMode.ferry,
              badge: 'FERRY',
              routeTitle: variant.routeName,
              fromStop: sFrom.name,
              toStop: sTo.name,
              fromKey: KolkataGeo.normalizeStopKey(sFrom.name),
              toKey: KolkataGeo.normalizeStopKey(sTo.name),
              fromCoord: sFrom.latLng,
              toCoord: sTo.latLng,
              rideMins: mins,
              waitMins: (variant.headwayPeakMins / 2).round().clamp(4, 15),
              fareInr: variant.fareMin,
              distanceKm: km,
              timingText: '${variant.firstService}–${variant.lastService} • Every ${variant.headwayPeakMins}m',
              detailRoute: variant,
              stops: variant.stops.sublist(i, tIdx + 1).map((s) => s.name).toList(),
            ),
          );
        }
      }
    }

    // 3. Train legs arriving near destination
    for (final corridor in _railCorridors) {
      for (final dir in corridor.directions) {
        final aIdx = dir.stops.lastIndexWhere(
          (s) => _stopOrProximityMatches(s.name, s.latLng, toTerms, toCoord, maxKm: 0.85),
        );
        if (aIdx <= 0) continue;
        for (int i = 0; i < aIdx; i++) {
          legs.add(_buildTrainLegMatch(corridor, dir, i, aIdx, now));
        }
      }
    }

    // 4. Metro legs ending near destination
    legs.addAll(_collectMetroLegsTo(toTerms, toCoord));

    // 5. Bus legs ending at destination
    final bestBusByStart = <String, _LegMatch>{};
    for (final rec in BusDataService().rawRecords) {
      final tIdx = BusDataService.findStopIndexPublic(rec.stopsLower, toTerms);
      if (tIdx <= 0) continue;
      final sToName = rec.stops[tIdx];
      final sToCoord = KolkataGeo.lookupExactCoord(sToName);
      for (int i = 0; i < tIdx; i++) {
        final sFromName = rec.stops[i];
        final fromKey = KolkataGeo.normalizeStopKey(sFromName);
        if (fromKey.isEmpty) continue;
        final sFromCoord = KolkataGeo.lookupExactCoord(sFromName);
        final stopDiff = tIdx - i;
        final km = _segmentKm(sFromCoord, sToCoord, stopDiff * 1.15);
        final mins = sFromCoord != null && sToCoord != null
            ? max(5, (km / 17.5 * 60).round())
            : max(5, (stopDiff * 3.0).round());
        final fare = BusDataService.calculateBusFare(rec.busType, stopDiff);
        final cand = _LegMatch(
          mode: TransitMode.bus,
          badge: rec.routeNo,
          routeTitle: '${rec.origin} ➔ ${rec.destination}',
          fromStop: sFromName,
          toStop: sToName,
          fromKey: fromKey,
          toKey: KolkataGeo.normalizeStopKey(sToName),
          fromCoord: sFromCoord,
          toCoord: sToCoord,
          rideMins: mins,
          waitMins: 5,
          fareInr: fare,
          distanceKm: km,
          timingText: 'Runs daily • Every 8–12 mins',
          busRouteId: rec.id,
          busType: rec.busType,
          stops: rec.stops.sublist(i, tIdx + 1),
        );
        if (!bestBusByStart.containsKey(fromKey) || cand.rideMins < bestBusByStart[fromKey]!.rideMins) {
          bestBusByStart[fromKey] = cand;
        }
      }
    }
    legs.addAll(bestBusByStart.values);
    return legs;
  }

  List<_LegMatch> _collectMetroLegsFrom(List<String> fromTerms, LatLng? fromCoord) {
    final legs = <_LegMatch>[];
    final stations = MetroService.defaultMetroStations;
    for (final st in stations) {
      final c = KolkataGeo.lookupExactCoord(st.stationName);
      if (!_stopOrProximityMatches(st.stationName, c, fromTerms, fromCoord, maxKm: 0.7)) continue;
      for (final other in stations) {
        if (other.stationName == st.stationName || other.lineId != st.lineId) continue;
        final plan = MetroService.planJourney(st.stationName, other.stationName);
        final oc = KolkataGeo.lookupExactCoord(other.stationName);
        final km = _segmentKm(c, oc, plan.distanceKm);
        legs.add(
          _LegMatch(
            mode: TransitMode.metro,
            badge: 'METRO',
            routeTitle: st.lineName,
            fromStop: st.stationName,
            toStop: other.stationName,
            fromKey: KolkataGeo.normalizeStopKey(st.stationName),
            toKey: KolkataGeo.normalizeStopKey(other.stationName),
            fromCoord: c,
            toCoord: oc,
            rideMins: max(3, plan.durationMins),
            waitMins: 4,
            fareInr: plan.fare,
            distanceKm: km,
            timingText: 'Every 6–12 mins (06:50 AM – 09:40 PM)',
            metroPlan: plan,
            stops: plan.stations.map((ms) => ms.stationName).toList(),
          ),
        );
      }
    }
    return legs;
  }

  List<_LegMatch> _collectMetroLegsTo(List<String> toTerms, LatLng? toCoord) {
    final legs = <_LegMatch>[];
    final stations = MetroService.defaultMetroStations;
    for (final st in stations) {
      final c = KolkataGeo.lookupExactCoord(st.stationName);
      if (!_stopOrProximityMatches(st.stationName, c, toTerms, toCoord, maxKm: 0.7)) continue;
      for (final other in stations) {
        if (other.stationName == st.stationName || other.lineId != st.lineId) continue;
        final plan = MetroService.planJourney(other.stationName, st.stationName);
        final oc = KolkataGeo.lookupExactCoord(other.stationName);
        final km = _segmentKm(oc, c, plan.distanceKm);
        legs.add(
          _LegMatch(
            mode: TransitMode.metro,
            badge: 'METRO',
            routeTitle: st.lineName,
            fromStop: other.stationName,
            toStop: st.stationName,
            fromKey: KolkataGeo.normalizeStopKey(other.stationName),
            toKey: KolkataGeo.normalizeStopKey(st.stationName),
            fromCoord: oc,
            toCoord: c,
            rideMins: max(3, plan.durationMins),
            waitMins: 4,
            fareInr: plan.fare,
            distanceKm: km,
            timingText: 'Every 6–12 mins (06:50 AM – 09:40 PM)',
            metroPlan: plan,
            stops: plan.stations.map((ms) => ms.stationName).toList(),
          ),
        );
      }
    }
    return legs;
  }

  /// Groups break journeys into 3 collapsible strategies: Less Time, Less Changes, Cheapest.
  ({
    List<BreakJourneyOption> lessTime,
    List<BreakJourneyOption> lessChanges,
    List<BreakJourneyOption> cheapest,
  }) suggestGroupedBreakJourneys(String from, String to, {DateTime? atTime}) {
    final pool = suggestBreakJourneys(from, to, limit: 45, atTime: atTime);
    if (pool.isEmpty) {
      return (lessTime: const [], lessChanges: const [], cheapest: const []);
    }

    final lessTime = List<BreakJourneyOption>.from(pool)
      ..sort((a, b) {
        final c = a.totalEtaMins.compareTo(b.totalEtaMins);
        if (c != 0) return c;
        return a.legs.length.compareTo(b.legs.length);
      });

    final lessChanges = List<BreakJourneyOption>.from(pool)
      ..sort((a, b) {
        final c = a.legs.length.compareTo(b.legs.length);
        if (c != 0) return c;
        final e = a.totalEtaMins.compareTo(b.totalEtaMins);
        if (e != 0) return e;
        return a.totalFareInr.compareTo(b.totalFareInr);
      });

    final cheapest = List<BreakJourneyOption>.from(pool)
      ..sort((a, b) {
        final c = a.totalFareInr.compareTo(b.totalFareInr);
        if (c != 0) return c;
        return a.totalEtaMins.compareTo(b.totalEtaMins);
      });

    return (
      lessTime: lessTime.take(8).toList(),
      lessChanges: lessChanges.take(8).toList(),
      cheapest: cheapest.take(8).toList(),
    );
  }

  static double _segmentKm(LatLng? a, LatLng? b, double fallbackKm) {
    if (a != null && b != null) {
      final d = KolkataGeo.haversineKm(a, b) * 1.15;
      return double.parse(max(0.6, d).toStringAsFixed(1));
    }
    return double.parse(max(0.8, fallbackKm).toStringAsFixed(1));
  }
}
