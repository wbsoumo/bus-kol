import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'kolkata_geo.dart';
import 'multi_transit_service.dart';

class ExternalAppLauncher {
  static const MethodChannel _channel = MethodChannel('com.cholokolkata/app_updater');

  static const String pkgGoogleMaps = 'com.google.android.apps.maps';
  static const String pkgAamarKolkataMetro = 'org.cris.kmmts';
  static const String pkgUber = 'com.ubercab';
  static const String pkgRapido = 'com.rapido.passenger';
  static const String pkgYatriSathi = 'in.juspay.jatrisaathi';

  static Future<String> openExternalApp({
    required String packageName,
    String deepLinkUrl = '',
    bool fallbackToBrowser = false,
  }) async {
    try {
      final res = await _channel.invokeMethod<String>('openExternalApp', {
        'packageName': packageName,
        'deepLinkUrl': deepLinkUrl,
        'fallbackToBrowser': fallbackToBrowser,
      });
      return res ?? 'failed';
    } catch (_) {
      return 'failed';
    }
  }

  /// Opens Official Aamar Kolkata Metro app (or Play Store listing if not installed).
  static Future<String> openAamarKolkataMetro() {
    return openExternalApp(packageName: pkgAamarKolkataMetro);
  }

  /// Opens Uber app pre-filled with pickup & dropoff coordinates/names (or Play Store).
  static Future<String> openUberRide({
    required String fromName,
    required String toName,
    LatLng? fromCoord,
    LatLng? toCoord,
  }) {
    final pCoord = fromCoord ?? KolkataGeo.lookupExactCoord(fromName);
    final dCoord = toCoord ?? KolkataGeo.lookupExactCoord(toName);

    final params = <String, String>{'action': 'setPickup'};
    if (pCoord != null && fromName.trim().isNotEmpty) {
      params['pickup[latitude]'] = pCoord.latitude.toStringAsFixed(6);
      params['pickup[longitude]'] = pCoord.longitude.toStringAsFixed(6);
      params['pickup[nickname]'] = fromName.trim();
      params['pickup[formatted_address]'] = '${fromName.trim()}, Kolkata';
    } else {
      params['pickup'] = 'my_location';
    }

    if (dCoord != null && toName.trim().isNotEmpty) {
      params['dropoff[latitude]'] = dCoord.latitude.toStringAsFixed(6);
      params['dropoff[longitude]'] = dCoord.longitude.toStringAsFixed(6);
      params['dropoff[nickname]'] = toName.trim();
      params['dropoff[formatted_address]'] = '${toName.trim()}, Kolkata';
    } else if (toName.trim().isNotEmpty) {
      params['dropoff[nickname]'] = toName.trim();
      params['dropoff[formatted_address]'] = '${toName.trim()}, Kolkata';
    }

    final uri = Uri.https('m.uber.com', '/ul/', params);
    return openExternalApp(packageName: pkgUber, deepLinkUrl: uri.toString());
  }

  /// Copies selected route points & launches Rapido (or Play Store).
  static Future<String> openRapidoRide({
    required String fromName,
    required String toName,
  }) async {
    final cleanFrom = fromName.trim();
    final cleanTo = toName.trim();
    if (cleanFrom.isNotEmpty || cleanTo.isNotEmpty) {
      await Clipboard.setData(
        ClipboardData(text: cleanTo.isEmpty ? cleanFrom : '$cleanFrom ➔ $cleanTo'),
      );
    }
    return openExternalApp(packageName: pkgRapido);
  }

  /// Copies selected route points & launches Yatri Sathi (or Play Store).
  static Future<String> openYatriSathiRide({
    required String fromName,
    required String toName,
  }) async {
    final cleanFrom = fromName.trim();
    final cleanTo = toName.trim();
    if (cleanFrom.isNotEmpty || cleanTo.isNotEmpty) {
      await Clipboard.setData(
        ClipboardData(text: cleanTo.isEmpty ? cleanFrom : '$cleanFrom ➔ $cleanTo'),
      );
    }
    return openExternalApp(packageName: pkgYatriSathi);
  }

  /// Opens Google Maps with point-by-point markers (origin -> transfer points -> destination) for a break journey.
  static Future<String> openGoogleMapsBreakJourney(BreakJourneyOption option) {
    final points = <String>[];
    String formatPoint(String stopName, LatLng? coord) {
      final c = coord ?? KolkataGeo.lookupExactCoord(stopName);
      if (c != null) {
        return '${c.latitude.toStringAsFixed(6)},${c.longitude.toStringAsFixed(6)}';
      }
      return '$stopName, Kolkata, West Bengal';
    }

    if (option.legs.isEmpty) return Future.value('failed');

    points.add(formatPoint(option.legs.first.fromStop, option.legs.first.fromCoord));
    for (int i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      if (i > 0) {
        final boardPt = formatPoint(leg.fromStop, leg.fromCoord);
        if (points.last != boardPt) points.add(boardPt);
      }
      final alightPt = formatPoint(leg.toStop, leg.toCoord);
      if (points.last != alightPt) points.add(alightPt);
    }

    final origin = points.first;
    final destination = points.last;
    final waypoints = points.length > 2 ? points.sublist(1, points.length - 1) : <String>[];

    final params = <String, String>{
      'api': '1',
      'origin': origin,
      'destination': destination,
      'travelmode': 'driving',
    };
    if (waypoints.isNotEmpty) {
      params['waypoints'] = waypoints.take(8).join('|');
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', params);
    return openExternalApp(
      packageName: pkgGoogleMaps,
      deepLinkUrl: uri.toString(),
      fallbackToBrowser: true,
    );
  }
}
