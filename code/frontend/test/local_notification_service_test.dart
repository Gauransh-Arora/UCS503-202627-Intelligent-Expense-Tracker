import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/models/notification_model.dart';
import 'package:intelligent_expense_tracker/services/local_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalNotificationService Unit Tests', () {
    test('Notification tap callback registers and triggers', () {
      String? tappedPayload;
      LocalNotificationService.onNotificationTap = (payload) {
        tappedPayload = payload;
      };

      LocalNotificationService.onNotificationTap?.call('expenses');
      expect(tappedPayload, equals('expenses'));
    });

    test('showExpenseCapturedAlert executes without throwing', () async {
      await expectLater(
        LocalNotificationService.showExpenseCapturedAlert(
          merchant: 'Swiggy',
          amount: 350.0,
        ),
        completes,
      );
    });

    test('showSpendingAnomalyAlert executes without throwing', () async {
      await expectLater(
        LocalNotificationService.showSpendingAnomalyAlert(
          title: 'Unusual Spend Detected',
          description: '₹4,500 spent on Electronics vs avg ₹800',
        ),
        completes,
      );
    });

    test('showBillDueAlert executes without throwing', () async {
      await expectLater(
        LocalNotificationService.showBillDueAlert(
          merchant: 'Electricity Bill',
          amount: 1450.0,
          dueDate: '10 Nov',
        ),
        completes,
      );
    });

    test(
      'showFromNotificationItems dispatches item notifications safely',
      () async {
        final items = <NotificationItemModel>[
          NotificationItemModel(
            id: 'notif_1',
            userId: 'user_test',
            title: 'Bill Reminder',
            message: 'Wifi bill is due tomorrow',
            notificationType: 'recurring_reminder',
            isRead: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          NotificationItemModel(
            id: 'notif_2',
            userId: 'user_test',
            title: 'Shared Split Settled',
            message: 'Rahul settled ₹500',
            notificationType: 'shared_debt',
            isRead: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ];

        await expectLater(
          LocalNotificationService.showFromNotificationItems(items),
          completes,
        );
      },
    );
  });
}
