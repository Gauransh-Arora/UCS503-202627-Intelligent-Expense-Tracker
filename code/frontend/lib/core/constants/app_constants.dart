class AppConstants {
  AppConstants._();

  static const String appName = 'Expense Tracker';
  static const String appTagline = 'Track smarter. Spend better.';

  // Route names
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeHome = '/home';
  static const String routeExpenses = '/expenses';
  static const String routeExpenseDetail = '/expenses/:id';
  static const String routeAddExpense = '/add-expense';
  static const String routeManualExpense = '/add-expense/manual';
  static const String routeCapture = '/add-expense/capture';
  static const String routeImagePreview = '/add-expense/image-preview';
  static const String routeProcessing = '/add-expense/processing';
  static const String routeOcrReview = '/add-expense/ocr-review';
  static const String routeBankStatement = '/add-expense/bank-statement';
  static const String routeSplit = '/split/:expenseId';
  static const String routeSharedExpenses = '/shared-expenses';
  static const String routeAnalytics = '/analytics';
  static const String routeInsights = '/insights';
  static const String routeRecurring = '/recurring';
  static const String routeWishlist = '/wishlist';
  static const String routePurchaseReadiness = '/wishlist/:itemId';
  static const String routeAskExpenses = '/ask-expenses';
  static const String routeProfile = '/profile';

  // Categories
  static const List<String> categories = [
    'Food & Dining',
    'Travel',
    'Shopping',
    'Bills',
    'Health',
    'Entertainment',
    'Education',
    'Other',
  ];

  // Payment Methods
  static const List<String> paymentMethods = [
    'UPI',
    'Credit Card',
    'Debit Card',
    'Cash',
    'Net Banking',
    'Wallet',
  ];

  // Split methods
  static const String splitEqual = 'equal';
  static const String splitPercentage = 'percentage';
  static const String splitCustom = 'custom';

  // Wishlist readiness verdicts
  static const String readinessComfortable = 'Comfortable';
  static const String readinessPossible = 'Possible';
  static const String readinessNotRecommended = 'Not Recommended';
}
