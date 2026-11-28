import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cholo_kolkata/services/bus_data_service.dart';
import 'package:cholo_kolkata/services/kolkata_geo.dart';
import 'package:cholo_kolkata/services/multi_transit_service.dart';

void main() {
  setUpAll(() {
    KolkataGeo.loadFromJsonString(File('assets/kolkata_stop_coords.json').readAsStringSync());
    BusDataService().loadFromJsonStrings(
      File('assets/kolkata_bus_routes.json').readAsStringSync(),
      File('assets/kolkata_stops.json').readAsStringSync(),
    );
    MultiTransitService().loadFromJsonStrings(
      autoJson: File('assets/kolkata_auto_routes.json').readAsStringSync(),
      ferryJson: File('assets/kolkata_ferry_routes.json').readAsStringSync(),
      railJson: File('assets/kolkata_rail_routes.json').readAsStringSync(),
    );
  });

  test('loads all 1,403 auto routes, 10 ferry routes, and 27 rail corridors offline', () {
    final svc = MultiTransitService();
    expect(svc.allAutoRoutes.length, 1403);
    expect(svc.allFerryRoutes.length, 10);
    expect(svc.allRailCorridors.length, 27);
  });

  test('auto and ferry searches work offline with coordinates and timings', () {
    final svc = MultiTransitService();
    final autoRes = svc.searchAutoRoutes('Phoolbagan', 'Karunamoyee');
    expect(autoRes, isNotEmpty);
    expect(autoRes.first.stops.any((s) => s.lat != null && s.lon != null), isTrue);
    expect(autoRes.first.timingSummary, contains('Every'));

    final mergedAutoRes = svc.searchAutoRoutes('Airport Gate 1', 'Ultadanga');
    expect(mergedAutoRes, isNotEmpty);
    expect(mergedAutoRes.first.stops.every((s) => s.lat != null && s.lon != null), isTrue);

    final wbAuto = svc.searchAutoRoutes('Durgapur', '');
    expect(wbAuto, isNotEmpty);

    final wbBus = BusDataService().searchRoutes('Barasat', 'Digha');
    expect(wbBus, isNotEmpty);
    final wbBusRev = BusDataService().searchRoutes('Digha', 'Barasat');
    expect(wbBusRev, isNotEmpty);

    final ferryRes = svc.searchFerryRoutes('Howrah', 'Fairlie');
    expect(ferryRes, isNotEmpty);
    expect(ferryRes.first.stops.every((s) => s.lat != null && s.lon != null), isTrue);
    expect(ferryRes.first.fareText, contains('₹'));
  });

  test('break journey suggestions include train + bus + auto and always sort strictly by ETA', () {
    final svc = MultiTransitService();

    // Long suburban -> metro/east corridor where Train + Bus / Auto beats buses
    final suggestions = svc.suggestBreakJourneys(
      'Barrackpore',
      'Sector V',
      atTime: DateTime(2026, 11, 28, 9, 15),
    );
    expect(suggestions, isNotEmpty);
    expect(suggestions.any((s) => s.usesTrain), isTrue);

    // Strictly ascending ETA order check
    for (int i = 1; i < suggestions.length; i++) {
      expect(
        suggestions[i].totalEtaMins,
        greaterThanOrEqualTo(suggestions[i - 1].totalEtaMins),
        reason: 'Break journeys must always be sorted by shortest ETA first',
      );
    }

    // Cross-river break journey where no direct bus matches Bandhaghat -> Sector V
    final crossRiver = svc.suggestBreakJourneys(
      'Bandhaghat',
      'Sector V',
      atTime: DateTime(2026, 11, 28, 10, 0),
    );
    expect(crossRiver, isNotEmpty);
    for (int i = 1; i < crossRiver.length; i++) {
      expect(crossRiver[i].totalEtaMins, greaterThanOrEqualTo(crossRiver[i - 1].totalEtaMins));
    }

    // Grouped collapsible strategies: Less Time, Less Changes, Cheapest
    final grouped = svc.suggestGroupedBreakJourneys(
      'Barrackpore',
      'Sector V',
      atTime: DateTime(2026, 11, 28, 9, 15),
    );
    expect(grouped.lessTime, isNotEmpty);
    expect(grouped.lessChanges, isNotEmpty);
    expect(grouped.cheapest, isNotEmpty);
    for (int i = 1; i < grouped.lessTime.length; i++) {
      expect(grouped.lessTime[i].totalEtaMins, greaterThanOrEqualTo(grouped.lessTime[i - 1].totalEtaMins));
    }
    for (int i = 1; i < grouped.cheapest.length; i++) {
      expect(grouped.cheapest[i].totalFareInr, greaterThanOrEqualTo(grouped.cheapest[i - 1].totalFareInr));
    }
    expect(grouped.lessTime.first.legs.first.stops, isNotEmpty);
  });
}
