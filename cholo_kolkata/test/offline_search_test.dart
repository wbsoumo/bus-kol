import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cholo_kolkata/services/bus_data_service.dart';
import 'package:cholo_kolkata/services/kolkata_stops.dart';

void main() {
  setUpAll(() {
    final routesJson = File('assets/kolkata_bus_routes.json').readAsStringSync();
    final stopsJson = File('assets/kolkata_stops.json').readAsStringSync();
    BusDataService().loadFromJsonStrings(routesJson, stopsJson);
  });

  test('loads all 2,172 routes and 2,327+ stops offline', () {
    expect(BusDataService().totalRoutesCount, 2172);
    expect(KolkataStops.totalStopsCount, greaterThanOrEqualTo(2327));
  });

  test('stop autocomplete searches all 2,327 stops with aliases', () {
    final howrah = KolkataStops.searchLocal('Howrah Stn', limit: 15);
    expect(howrah, isNotEmpty);

    final minor = KolkataStops.searchLocal('Tarakeswar', limit: 15);
    expect(minor.any((s) => s.name.toLowerCase().contains('tarakeswar')), isTrue);

    final sec5 = KolkataStops.searchLocal('Sector 5', limit: 15);
    expect(sec5.any((s) => s.name.toLowerCase().contains('sector v')), isTrue);
  });

  test('bus number search works offline with hyphen normalization', () {
    final res215 = BusDataService().searchRoutes('215A', '');
    expect(res215, isNotEmpty);

    final resS12 = BusDataService().searchBusNumbers('S12', uniqueByRouteNo: false);
    expect(resS12.any((r) => r.routeNo.toUpperCase() == 'S-12'), isTrue);

    final res46A = BusDataService().searchBusNumbers('46A', uniqueByRouteNo: false);
    expect(res46A, isNotEmpty);
  });

  test('direct stop-to-stop search and route details work offline', () {
    final direct = BusDataService().searchRoutes('Howrah Station', 'Sector V');
    expect(direct, isNotEmpty);
    expect(direct.any((r) => r.routeNo == '215A'), isTrue);

    final airport = BusDataService().searchRoutes('Esplanade', 'Airport');
    expect(airport, isNotEmpty);

    final first = direct.first;
    final details = BusDataService().getRouteDetails(
      first.routeNo,
      routeId: first.id,
      from: 'Howrah Station',
      to: 'Sector V',
    );
    expect(details, isNotNull);
    expect((details!['stops'] as List), isNotEmpty);
  });

  test('1-transfer route finder works offline when needed', () {
    final transfers = BusDataService().searchTransfers('Baruipur', 'Dakshineswar');
    expect(transfers, isNotEmpty);
  });
}
