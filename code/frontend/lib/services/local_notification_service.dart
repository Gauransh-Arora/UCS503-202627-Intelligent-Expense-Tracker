import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import '../models/notification_model.dart';

/// Local Push Notification Service.
///
/// Dispatches native OS system-tray notifications for:
/// - Spending anomaly alerts
/// - Upcoming recurring bills due
/// - Settlement debts & shared expenses
/// - Wishlist savings goal milestones
/// - Shared intent auto-captures (UPI SMS / receipt uploads)
class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Callback when a user taps on a notification
  static ValueChanged<String?>? onNotificationTap;

  /// Channel ID and details for high-priority personal finance alerts
  static const String _channelId = 'expense_tracker_alerts';
  static const String _channelName = 'Expense & Budget Alerts';
  static const String _channelDesc =
      'Real-time spending anomalies, bill reminders, and settlements.';

  /// Initialize the notification plugin across Android, iOS, and Linux.
  static Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open Notification',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          onNotificationTap?.call(response.payload);
        },
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('LocalNotificationService init error: $e');
    }
  }

  /// Request runtime permissions (especially Android 13+ and iOS).
  static Future<bool?> requestPermissions() async {
    try {
      final androidPlatform = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlatform != null) {
        return await androidPlatform.requestNotificationsPermission();
      }

      final iosPlatform = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlatform != null) {
        return await iosPlatform.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('Request permissions error: $e');
    }
    return true;
  }

  /// Base method to show a high-priority system-tray push notification.
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await init();
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Expense Alert',
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF164B35), // Dark forest green brand color
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const linuxDetails = LinuxNotificationDetails();

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show push notification: $e');
    }
  }

  /// Push notification when a UPI SMS or receipt is captured.
  static Future<void> showExpenseCapturedAlert({
    required String merchant,
    required double amount,
  }) async {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final formatted = currencyFormatter.format(amount);

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Expense Recorded: $formatted',
      body: 'Successfully logged transaction at $merchant.',
      payload: 'expenses',
    );
  }

  /// Push notification for spending anomalies.
  static Future<void> showSpendingAnomalyAlert({
    required String title,
    required String description,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: description,
      payload: 'notifications',
    );
  }

  /// Push notification for upcoming bills due.
  static Future<void> showBillDueAlert({
    required String merchant,
    required double amount,
    required String dueDate,
  }) async {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final formatted = currencyFormatter.format(amount);

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Upcoming Bill Reminder',
      body: '$merchant of $formatted is due on $dueDate.',
      payload: 'recurring',
    );
  }

  /// Dispatch push notifications for newly generated auto-notifications from backend.
  static Future<void> showFromNotificationItems(
    List<NotificationItemModel> items,
  ) async {
    for (int i = 0; i < items.length && i < 3; i++) {
      final item = items[i];
      String payload = 'notifications';
      final type = item.notificationType.toLowerCase();
      if (type == 'wishlist_update' || item.title.toLowerCase().contains('wishlist')) {
        payload = 'wishlist';
      } else if (type == 'recurring_due') {
        payload = 'recurring';
      } else if (type == 'split_debt') {
        payload = 'shared_expenses';
      }
      await showNotification(
        id: item.id.hashCode,
        title: item.title,
        body: item.message,
        payload: payload,
      );
    }
  }
}
