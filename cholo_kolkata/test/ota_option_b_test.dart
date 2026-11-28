import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cholo_kolkata/services/kolkata_geo.dart';
import 'package:cholo_kolkata/services/multi_transit_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('KolkataGeo.applyOtaCoords persists and reloads OTA stop coordinates', () async {
    SharedPreferences.setMockInitialValues({});

    final payload = json.encode({
      'Test Metro Gate (New)': [22.6123, 88.4123],
      'Dakshineswar': [22.6534, 88.3582],
    });

    final ok = await KolkataGeo.applyOtaCoords(
      version: '2.5.1',
      coordsJson: payload,
    );
    expect(ok, isTrue);
    expect(KolkataGeo.coordsVersion, '2.5.1');
    expect(KolkataGeo.totalCoordsCount, 2);

    final resolved = KolkataGeo.lookupExactCoord('Test Metro Gate');
    expect(resolved, isNotNull);
    expect(resolved!.latitude, closeTo(22.6123, 0.0001));
    expect(resolved.longitude, closeTo(88.4123, 0.0001));

    // Empty OTA map should be rejected safely without wiping existing data
    final emptyOk = await KolkataGeo.applyOtaCoords(version: '2.5.2', coordsJson: '{}');
    expect(emptyOk, isFalse);
    expect(KolkataGeo.totalCoordsCount, 2);
  });

  test('MultiTransitService.applyOtaAutoRoutes persists gzipped auto routes offline', () async {
    SharedPreferences.setMockInitialValues({});
    final multi = MultiTransitService();

    final autoPayload = json.encode([
      {
        'id': 99001,
        'rid': 'auto_ota_test_corridor',
        'r': 'A-99',
        'rn': 'TestOrigin - TestDest',
        'f': 'TestOrigin',
        't': 'TestDest',
        'hwP': 4,
        'hwO': 8,
        'fs': '06:00',
        'ls': '22:00',
        'fMin': 12,
        'fMax': 18,
        'km': 4.2,
        'dur': 14,
        'nt': 'OTA dynamic auto corridor test',
        'stops': [
          {'n': 'TestOrigin', 'lat': 22.58, 'lng': 88.40},
          {'n': 'MidPoint', 'lat': 22.585, 'lng': 88.41},
          {'n': 'TestDest', 'lat': 22.59, 'lng': 88.42},
        ],
      }
    ]);

    final applied = await multi.applyOtaAutoRoutes(
      version: '2.5.1',
      autoJson: autoPayload,
    );
    expect(applied, isTrue);
    expect(multi.autoVersion, '2.5.1');
    expect(multi.totalAutoRoutesCount, 1);

    final hits = multi.searchAutoRoutes('TestOrigin', 'TestDest');
    expect(hits.length, 1);
    expect(hits.first.code, 'A-99');
    expect(hits.first.fareMin, 12);

    // Empty OTA list should be rejected safely
    final emptyApplied = await multi.applyOtaAutoRoutes(version: '2.5.2', autoJson: '[]');
    expect(emptyApplied, isFalse);
    expect(multi.totalAutoRoutesCount, 1);

    // Verify compressed key stored in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ota_auto_routes_gz_v1'), isNotNull);
    expect(prefs.getString('ota_auto_version'), '2.5.1');
  });
}
