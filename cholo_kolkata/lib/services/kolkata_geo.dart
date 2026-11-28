import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KolkataGeo {
  static const String _prefCoordsGzKey = 'ota_stop_coords_gz_v1';
  static const String _prefCoordsVersionKey = 'ota_coords_version';

  static Map<String, LatLng> _assetStopCoords = {};
  static bool _isInitialized = false;
  static String _coordsVersion = '2.4.0';

  static int get totalCoordsCount => _assetStopCoords.length;
  static String get coordsVersion => _coordsVersion;

  static String normalizeStopKey(String raw) {
    final noParen = raw.toLowerCase().replaceAll(RegExp(r'\([^)]*\)'), ' ');
    return noParen.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Future<void> init() async {
    if (_isInitialized) return;
    // 1. Prefer locally cached OTA coordinates if synced
    try {
      final prefs = await SharedPreferences.getInstance();
      final coordsGz = prefs.getString(_prefCoordsGzKey);
      if (coordsGz != null && coordsGz.isNotEmpty) {
        final coordsJson = utf8.decode(gzip.decode(base64.decode(coordsGz)));
        loadFromJsonString(coordsJson);
        if (_assetStopCoords.isNotEmpty) {
          _coordsVersion = prefs.getString(_prefCoordsVersionKey) ?? _coordsVersion;
          return;
        }
      }
    } catch (_) {
      // Fall back to bundled asset coordinates
    }

    // 2. Load bundled offline stop coordinates asset
    try {
      final jsonStr = await rootBundle.loadString('assets/kolkata_stop_coords.json');
      loadFromJsonString(jsonStr);
    } catch (_) {
      _isInitialized = true;
    }
  }

  static void loadFromJsonString(String jsonStr) {
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    final parsed = <String, LatLng>{};
    for (final entry in decoded.entries) {
      final v = entry.value;
      double? lat;
      double? lng;
      if (v is List && v.length >= 2) {
        lat = (v[0] as num?)?.toDouble();
        lng = (v[1] as num?)?.toDouble();
      } else if (v is Map) {
        lat = (v['lat'] as num?)?.toDouble();
        lng = ((v['lng'] ?? v['lon']) as num?)?.toDouble();
      }
      if (lat == null || lng == null) continue;
      final norm = normalizeStopKey(entry.key);
      if (norm.isEmpty) continue;
      parsed[norm] = LatLng(lat, lng);
    }
    if (parsed.isNotEmpty || _assetStopCoords.isEmpty) {
      _assetStopCoords = parsed;
    }
    _isInitialized = true;
  }

  /// Applies freshly synced OTA stop coordinates in memory and persists compressed on device.
  static Future<bool> applyOtaCoords({
    required String version,
    required String coordsJson,
  }) async {
    try {
      final decoded = json.decode(coordsJson);
      if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
        return false;
      }
      loadFromJsonString(coordsJson);
      _coordsVersion = version;

      final prefs = await SharedPreferences.getInstance();
      final gz = base64.encode(gzip.encode(utf8.encode(coordsJson)));
      await prefs.setString(_prefCoordsGzKey, gz);
      await prefs.setString(_prefCoordsVersionKey, version);
      return true;
    } catch (_) {
      return false;
    }
  }

  static double haversineKm(LatLng a, LatLng b) {
    const p = 0.017453292519943295;
    final val = 0.5 -
        cos((b.latitude - a.latitude) * p) / 2 +
        cos(a.latitude * p) * cos(b.latitude * p) * (1 - cos((b.longitude - a.longitude) * p)) / 2;
    return 12742.0 * asin(sqrt(val.clamp(0.0, 1.0)));
  }

  static final Map<String, LatLng> landmarkCoordinates = {
    'howrah station': const LatLng(22.5850, 88.3426),
    'howrah': const LatLng(22.5850, 88.3426),
    'howrah maidan': const LatLng(22.5890, 88.3280),
    'sealdah station': const LatLng(22.5675, 88.3713),
    'sealdah': const LatLng(22.5675, 88.3713),
    'esplanade': const LatLng(22.5645, 88.3524),
    'bbd bagh': const LatLng(22.5732, 88.3468),
    'bbd bag': const LatLng(22.5732, 88.3468),
    'barabazar': const LatLng(22.5860, 88.3520),
    'burrabazar': const LatLng(22.5860, 88.3520),
    'mg road': const LatLng(22.5815, 88.3615),
    'girish park': const LatLng(22.5880, 88.3640),
    'vivekananda road': const LatLng(22.5895, 88.3670),
    'maniktala': const LatLng(22.5885, 88.3740),
    'khanna cinema': const LatLng(22.5920, 88.3800),
    'ultadanga': const LatLng(22.5975, 88.3887),
    'hudco': const LatLng(22.5980, 88.3910),
    'kankurgachi': const LatLng(22.5790, 88.3880),
    'phoolbagan': const LatLng(22.5720, 88.3900),
    'beleghata': const LatLng(22.5620, 88.3920),
    'saltlake pnb': const LatLng(22.5900, 88.4050),
    'salt lake pnb': const LatLng(22.5900, 88.4050),
    'saltlake c.a. block': const LatLng(22.5870, 88.4120),
    'saltlake ca block': const LatLng(22.5870, 88.4120),
    'city center 1': const LatLng(22.5890, 88.4080),
    'city center': const LatLng(22.5890, 88.4080),
    'bikash bhawan': const LatLng(22.5890, 88.4150),
    'karunamoyee': const LatLng(22.5860, 88.4230),
    'sector v': const LatLng(22.5804, 88.4378),
    'sector 5': const LatLng(22.5804, 88.4378),
    'salt lake sector v': const LatLng(22.5804, 88.4378),
    'college more': const LatLng(22.5750, 88.4320),
    'new town': const LatLng(22.5950, 88.4720),
    'eco space': const LatLng(22.5920, 88.4820),
    'chinar park': const LatLng(22.6280, 88.4410),
    'airport': const LatLng(22.6547, 88.4467),
    'dum dum': const LatLng(22.6225, 88.3780),
    'shyambazar': const LatLng(22.6035, 88.3715),
    'shobhabazar': const LatLng(22.5980, 88.3660),
    'central': const LatLng(22.5710, 88.3580),
    'chandni chowk': const LatLng(22.5665, 88.3540),
    'park street': const LatLng(22.5510, 88.3526),
    'maidan': const LatLng(22.5480, 88.3490),
    'rabindra sadan': const LatLng(22.5385, 88.3475),
    'exide': const LatLng(22.5385, 88.3475),
    'netaji bhavan': const LatLng(22.5310, 88.3465),
    'jatin das park': const LatLng(22.5220, 88.3460),
    'kalighat': const LatLng(22.5160, 88.3460),
    'rashbehari': const LatLng(22.5180, 88.3550),
    'gariahat': const LatLng(22.5195, 88.3653),
    'golpark': const LatLng(22.5130, 88.3670),
    'dhakuria': const LatLng(22.5080, 88.3670),
    'jadavpur': const LatLng(22.4988, 88.3713),
    'baghajatin': const LatLng(22.4850, 88.3760),
    'garia': const LatLng(22.4650, 88.3810),
    'kavi subhash': const LatLng(22.4636, 88.3970),
    'new garia': const LatLng(22.4636, 88.3970),
    'ruby hospital': const LatLng(22.5133, 88.4022),
    'ruby': const LatLng(22.5133, 88.4022),
    'science city': const LatLng(22.5390, 88.3960),
    'chingrighata': const LatLng(22.5660, 88.4030),
    'beleghata building more': const LatLng(22.5650, 88.3960),
    'taratala': const LatLng(22.5080, 88.3180),
    'behala chowrasta': const LatLng(22.4937, 88.3129),
    'chowrasta': const LatLng(22.4937, 88.3129),
    'behala sakher bazar': const LatLng(22.4840, 88.3120),
    'sakher bazar': const LatLng(22.4840, 88.3120),
    'thakurpukur': const LatLng(22.4660, 88.3100),
    'joka': const LatLng(22.4480, 88.3070),
    'ballygunge station': const LatLng(22.5230, 88.3680),
    'ballygunge': const LatLng(22.5230, 88.3680),
    'babughat': const LatLng(22.5670, 88.3420),
    'posta bazar': const LatLng(22.5875, 88.3540),
    'posta': const LatLng(22.5875, 88.3540),
    'nimtala': const LatLng(22.5930, 88.3560),
    'ahiritola': const LatLng(22.5960, 88.3580),
    'bagbazar': const LatLng(22.6020, 88.3620),
    'dakshineswar': const LatLng(22.6534, 88.3582),
    'baranagar': const LatLng(22.6410, 88.3690),
    'noapara': const LatLng(22.6360, 88.3740),
    'belgharia': const LatLng(22.6580, 88.3840),
    'agarpara': const LatLng(22.6780, 88.3820),
    'sodepur': const LatLng(22.6980, 88.3810),
    'barrackpore': const LatLng(22.7560, 88.3540),
    'barasat': const LatLng(22.7230, 88.4820),
    'madhyamgram': const LatLng(22.6980, 88.4590),
    'birati': const LatLng(22.6730, 88.4350),
    'kestopur': const LatLng(22.5950, 88.4230),
    'baguiati': const LatLng(22.6120, 88.4290),
    'teghoria': const LatLng(22.6230, 88.4350),
    'nagerbazar': const LatLng(22.6170, 88.3960),
    'dum dum cantt': const LatLng(22.6340, 88.4060),
    'jadavpur 8b': const LatLng(22.4988, 88.3713),
    'kasba': const LatLng(22.5180, 88.3850),
    'kalikapur': const LatLng(22.5020, 88.3980),
    'mukundapur': const LatLng(22.4900, 88.4020),
    'ajaynagar': const LatLng(22.4810, 88.3980),
    'patuli': const LatLng(22.4730, 88.3900),
    'sonarpur': const LatLng(22.4410, 88.4280),
    'alipore zoo': const LatLng(22.5350, 88.3320),
    'ekbalpur': const LatLng(22.5280, 88.3240),
    'khidirpur': const LatLng(22.5360, 88.3210),
    'kidderpore': const LatLng(22.5360, 88.3210),
    'metaburuz': const LatLng(22.5320, 88.2780),
    'santragachi': const LatLng(22.5780, 88.2830),
    'dankuni': const LatLng(22.6840, 88.2970),
    'serampore': const LatLng(22.7510, 88.3430),
    'bally': const LatLng(22.6490, 88.3450),
    'uttarpara': const LatLng(22.6680, 88.3440),
  };

  /// Matches a stop name to bundled GPS coordinates, landmark coordinates, or interpolates between boundaries
  static LatLng? lookupExactCoord(String stopName) {
    final k = normalizeStopKey(stopName);
    if (k.isNotEmpty && _assetStopCoords.containsKey(k)) {
      return _assetStopCoords[k];
    }
    final stripped = k
        .replaceAll(RegExp(r'\b(more|mord|stand|auto stand|bus stand|bus stop|crossing|junction|stn|station|bazar|bazaar|market|cinema|gate|mor|ghat)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.isNotEmpty && _assetStopCoords.containsKey(stripped)) {
      return _assetStopCoords[stripped];
    }
    final clean = stopName.toLowerCase().trim();
    for (final entry in landmarkCoordinates.entries) {
      if (clean == entry.key || clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Matches a stop name to a known landmark or interpolates between boundaries
  static LatLng resolveCoordinate(
    String stopName,
    int index,
    int total, {
    LatLng? originHint,
    LatLng? destHint,
  }) {
    final exact = lookupExactCoord(stopName);
    if (exact != null) return exact;

    final start = originHint ?? const LatLng(22.5850, 88.3426); // Default Howrah
    final end = destHint ?? const LatLng(22.5804, 88.4378);    // Default Sector V

    if (total <= 1) return start;

    final progress = index / (total - 1);
    final lat = start.latitude + (end.latitude - start.latitude) * progress;
    final lng = start.longitude + (end.longitude - start.longitude) * progress;

    // Small organic curve so straight line doesn't cut across rivers or obstacles
    final curve = sin(progress * pi) * 0.008 * (index % 2 == 0 ? 1 : -1);
    return LatLng(lat + curve, lng + curve);
  }

  /// Resolve full list of coordinates for a route
  static List<LatLng> resolveRouteCoordinates(List<dynamic> stops) {
    if (stops.isEmpty) return [];

    final total = stops.length;
    LatLng? startHint;
    LatLng? endHint;

    if (total > 0) {
      startHint = _quickFind(stops.first['stop_name']?.toString() ?? '');
    }
    if (total > 1) {
      endHint = _quickFind(stops.last['stop_name']?.toString() ?? '');
    }

    final result = <LatLng>[];
    for (int i = 0; i < total; i++) {
      final name = stops[i]['stop_name']?.toString() ?? '';
      result.add(resolveCoordinate(name, i, total, originHint: startHint, destHint: endHint));
    }
    return result;
  }

  static LatLng? _quickFind(String name) {
    return lookupExactCoord(name);
  }
}

