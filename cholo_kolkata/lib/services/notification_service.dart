import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _channel = MethodChannel('com.cholokolkata/live_notification');
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Function(Map<String, dynamic>)? onNotificationClicked;

  Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationOpened') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        onNotificationClicked?.call(data);
      }
    });
  }

  Future<Map<String, dynamic>?> checkInitialNotification() async {
    try {
      if (Platform.isAndroid) {
        final res = await _channel.invokeMethod('getInitialNotificationPayload');
        if (res != null) {
          return Map<String, dynamic>.from(res as Map);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Show or dynamically update ongoing Where Is My Train custom UI Live Notification
  Future<void> showLiveBusTrackingNotification({
    required int id,
    required String routeNo,
    required String origin,
    required String destination,
    required String nextStop,
    required double distanceToStopKm,
    required double speedKmh,
    required int etaMinutes,
    double progress = 0.25,
  }) async {
    final distStr = distanceToStopKm < 1.0
        ? '${(distanceToStopKm * 1000).round()} m'
        : '${distanceToStopKm.toStringAsFixed(1)} km';
    final speedStr = speedKmh > 2
        ? 'Speed: ${speedKmh.toStringAsFixed(0)} km/h • Kolkata Traffic Normal'
        : 'Speed: Stationary • Kolkata Traffic Normal';
    final etaStr = etaMinutes > 60
        ? '${etaMinutes ~/ 60} hr ${etaMinutes % 60} mins to $destination'
        : '$etaMinutes mins to $destination';

    // Calculate dynamic ETA arrival clock time
    final now = DateTime.now();
    final arrivalTime = now.add(Duration(minutes: etaMinutes));
    final arrivalTimeStr = DateFormat('hh:mm a').format(arrivalTime);

    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('showCustomLiveNotification', {
          'id': id,
          'routeNo': routeNo,
          'origin': origin,
          'destination': destination,
          'nextStop': nextStop,
          'distStr': distStr,
          'speedStr': speedStr,
          'etaStr': etaStr,
          'arrivalTimeStr': arrivalTimeStr,
          'progress': progress,
        });
      }
    } catch (_) {}
  }

  Future<void> cancelNotification(int id) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('cancelCustomLiveNotification', {'id': id});
      }
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    await cancelNotification(818);
  }
}
