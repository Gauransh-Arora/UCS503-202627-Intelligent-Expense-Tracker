import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/constants/app_constants.dart';
import 'services/share_intent_service.dart';

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
