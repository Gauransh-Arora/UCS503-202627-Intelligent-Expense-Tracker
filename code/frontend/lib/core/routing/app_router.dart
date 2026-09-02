import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/add_expense/manual_expense_screen.dart';
import '../../features/add_expense/ocr_flow/capture_screen.dart';
import '../../features/add_expense/bank_statement_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/recurring/recurring_screen.dart';
import '../../features/wishlist/wishlist_screen.dart';
import '../../features/ask_expenses/ask_expenses_screen.dart';
import '../../features/split_expense/shared_expenses_screen.dart';
import '../../navigation/main_navigation.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppConstants.routeSplash,
    routes: [
      GoRoute(
        path: AppConstants.routeSplash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppConstants.routeLogin,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppConstants.routeRegister,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppConstants.routeHome,
        builder: (context, state) => const MainNavigation(),
      ),
      GoRoute(
        path: AppConstants.routeManualExpense,
        builder: (context, state) => const ManualExpenseScreen(),
      ),
      GoRoute(
        path: AppConstants.routeCapture,
        builder: (context, state) => const CaptureScreen(type: 'receipt'),
      ),
      GoRoute(
        path: AppConstants.routeBankStatement,
        builder: (context, state) => const BankStatementScreen(),
      ),
      GoRoute(
        path: AppConstants.routeInsights,
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: AppConstants.routeRecurring,
        builder: (context, state) => const RecurringScreen(),
      ),
      GoRoute(
        path: AppConstants.routeWishlist,
        builder: (context, state) => const WishlistScreen(),
      ),
      GoRoute(
        path: AppConstants.routeAskExpenses,
        builder: (context, state) => const AskExpensesScreen(),
      ),
      GoRoute(
        path: AppConstants.routeSharedExpenses,
        builder: (context, state) => const SharedExpensesScreen(),
      ),
    ],
  );
}
