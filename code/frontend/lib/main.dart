import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/constants/app_constants.dart';
import 'services/share_intent_service.dart';
import 'services/local_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const IntelligentExpenseTrackerApp());
}

class IntelligentExpenseTrackerApp extends StatefulWidget {
  const IntelligentExpenseTrackerApp({super.key});

  @override
  State<IntelligentExpenseTrackerApp> createState() =>
      _IntelligentExpenseTrackerAppState();
}

class _IntelligentExpenseTrackerAppState
    extends State<IntelligentExpenseTrackerApp> {
  @override
  void initState() {
    super.initState();
    ShareIntentService.init();
    _initNotifications();
  }

  void _initNotifications() {
    LocalNotificationService.init().then((_) {
      LocalNotificationService.requestPermissions();
    });

    LocalNotificationService.onNotificationTap = (payload) {
      if (payload != null && payload.isNotEmpty) {
        if (payload == 'notifications') {
          AppRouter.router.push(AppConstants.routeNotifications);
        } else if (payload == 'recurring') {
          AppRouter.router.push(AppConstants.routeRecurring);
        } else if (payload == 'wishlist') {
          AppRouter.router.push(AppConstants.routeWishlist);
        } else if (payload == 'shared_expenses' || payload == 'split') {
          AppRouter.router.push(AppConstants.routeSharedExpenses);
        } else if (payload == 'expenses') {
          AppRouter.router.go(AppConstants.routeHome);
        } else if (payload.startsWith('/')) {
          AppRouter.router.push(payload);
        }
      }
    };
  }

  @override
  void dispose() {
    ShareIntentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
