import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _channel = MethodChannel('com.cholokolkata/live_notification');

  Future<void> init() async {
    // Channel initialization handled natively
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
