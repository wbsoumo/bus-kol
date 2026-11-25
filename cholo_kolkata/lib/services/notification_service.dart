import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Notification tapped
      },
    );

    // Request POST_NOTIFICATIONS permission on Android 13+
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Show or dynamically update ongoing WIMT-style Live Bus Tracking Notification
  Future<void> showLiveBusTrackingNotification({
    required int id,
    required String routeNo,
    required String origin,
    required String destination,
    required String nextStop,
    required double distanceToStopKm,
    required double speedKmh,
    required int etaMinutes,
  }) async {
    await init();

    final distStr = distanceToStopKm < 1.0
        ? '${(distanceToStopKm * 1000).round()} m'
        : '${distanceToStopKm.toStringAsFixed(1)} km';
    final speedStr = speedKmh > 2 ? '${speedKmh.toStringAsFixed(0)} km/h' : 'Stationary';
    final etaStr = etaMinutes > 60
        ? '${etaMinutes ~/ 60} hr ${etaMinutes % 60} mins'
        : '$etaMinutes mins';

    final title = 'CholoKolkata • $routeNo • now';
    final contentText = '$distStr to $nextStop';
    final summaryText = '$origin ➔ $destination';
    final bigText = '$distStr to $nextStop\n'
        'Speed: $speedStr • Kolkata Traffic Normal\n\n'
        '$origin ➔ $destination\n'
        '~$etaStr to $destination';

    final androidDetails = AndroidNotificationDetails(
      'cholo_kolkata_live_tracking',
      'Live Bus Trip Tracking',
      channelDescription: 'Ongoing live bus status, next stop distance, speed and ETA',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      color: const Color(0xFF00695C),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        bigText,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: summaryText,
        htmlFormatSummaryText: false,
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'dismiss_tracking',
          'Dismiss',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      contentText,
      notificationDetails,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
