import '../models/expense_model.dart';
import '../models/split_model.dart';
import '../models/wishlist_model.dart';
import '../models/analytics_model.dart';
import '../models/user_model.dart';

class MockData {
  MockData._();

  // ─── Current User ───────────────────────────────────────────────────────────

  static const UserModel currentUser = UserModel(
    id: 'user_001',
    name: 'Aashi Gupta',
    email: 'aashi@example.com',
    currency: 'INR',
  );

  // ─── Contacts for splitting ──────────────────────────────────────────────────

  static const List<UserModel> contacts = [
    UserModel(id: 'user_002', name: 'Rahul Sharma', email: 'rahul@example.com'),
    UserModel(id: 'user_003', name: 'Priya Singh', email: 'priya@example.com'),
    UserModel(id: 'user_004', name: 'Aman Verma', email: 'aman@example.com'),
    UserModel(id: 'user_005', name: 'Neha Kapoor', email: 'neha@example.com'),
    UserModel(id: 'user_006', name: 'Gauransh Arora', email: 'gauransh@example.com'),
  ];

  // ─── Expenses ───────────────────────────────────────────────────────────────

  static final List<ExpenseModel> expenses = [
    // Today (Sep 2)
    ExpenseModel(
      id: 'exp_001',
      merchant: 'Restaurant ABC',
      amount: 1250,
      date: DateTime(2026, 9, 2, 13, 30),
      category: 'Food & Dining',
      paymentMethod: 'UPI',
      source: 'ocr_receipt',
      items: [
        const ExpenseItemModel(id: 'i001', name: 'Paneer Butter Masala', quantity: 1, price: 380),
        const ExpenseItemModel(id: 'i002', name: 'Dal Makhani', quantity: 1, price: 320),
        const ExpenseItemModel(id: 'i003', name: 'Naan (4 pcs)', quantity: 1, price: 200),
        const ExpenseItemModel(id: 'i004', name: 'Lassi', quantity: 2, price: 100),
        const ExpenseItemModel(id: 'i005', name: 'GST & Service', quantity: 1, price: 150),
      ],
    ),
    ExpenseModel(
      id: 'exp_002',
      merchant: 'Uber',
      amount: 320,
      date: DateTime(2026, 9, 2, 9, 15),
      category: 'Travel',
      paymentMethod: 'UPI',
      source: 'ocr_upi',
    ),
    // Yesterday (Sep 1)
    ExpenseModel(
      id: 'exp_003',
      merchant: 'D-Mart',
      amount: 2340,
      date: DateTime(2026, 9, 1, 18, 45),
      category: 'Shopping',
      paymentMethod: 'Debit Card',
      source: 'manual',
      items: [
        const ExpenseItemModel(id: 'i006', name: 'Vegetables', quantity: 1, price: 450),
        const ExpenseItemModel(id: 'i007', name: 'Dairy Products', quantity: 1, price: 380),
        const ExpenseItemModel(id: 'i008', name: 'Snacks', quantity: 1, price: 620),
        const ExpenseItemModel(id: 'i009', name: 'Cleaning Supplies', quantity: 1, price: 890),
      ],
    ),
    ExpenseModel(
      id: 'exp_004',
      merchant: 'Swiggy',
      amount: 680,
      date: DateTime(2026, 9, 1, 20, 10),
      category: 'Food & Dining',
      paymentMethod: 'UPI',
      source: 'ocr_upi',
    ),
    // Aug 30
    ExpenseModel(
      id: 'exp_005',
      merchant: 'Netflix',
      amount: 649,
      date: DateTime(2026, 8, 30, 0, 0),
      category: 'Entertainment',
      paymentMethod: 'Credit Card',
      source: 'bank_statement',
      isRecurring: true,
    ),
    ExpenseModel(
      id: 'exp_006',
      merchant: 'Apollo Pharmacy',
      amount: 890,
      date: DateTime(2026, 8, 30, 15, 20),
      category: 'Health',
      paymentMethod: 'UPI',
      source: 'manual',
    ),
    // Aug 28
    ExpenseModel(
      id: 'exp_007',
      merchant: 'Amazon',
      amount: 3499,
      date: DateTime(2026, 8, 28, 11, 0),
      category: 'Shopping',
      paymentMethod: 'Credit Card',
      source: 'bank_statement',
    ),
    ExpenseModel(
      id: 'exp_008',
      merchant: 'Rapido',
      amount: 180,
      date: DateTime(2026, 8, 28, 8, 30),
      category: 'Travel',
      paymentMethod: 'UPI',
      source: 'ocr_upi',
    ),
    // Aug 26
    ExpenseModel(
      id: 'exp_009',
      merchant: 'Zomato',
      amount: 1120,
      date: DateTime(2026, 8, 26, 21, 0),
      category: 'Food & Dining',
      paymentMethod: 'UPI',
      source: 'ocr_upi',
      splitId: 'split_001',
    ),
    ExpenseModel(
      id: 'exp_010',
      merchant: 'Jio Postpaid',
      amount: 799,
      date: DateTime(2026, 8, 26, 0, 0),
      category: 'Bills',
      paymentMethod: 'Net Banking',
      source: 'bank_statement',
      isRecurring: true,
    ),
    // Aug 22
    ExpenseModel(
      id: 'exp_011',
      merchant: 'Spotify',
      amount: 119,
      date: DateTime(2026, 8, 22, 0, 0),
      category: 'Entertainment',
      paymentMethod: 'Credit Card',
      source: 'bank_statement',
      isRecurring: true,
    ),
    ExpenseModel(
      id: 'exp_012',
      merchant: 'Cafe Coffee Day',
      amount: 560,
      date: DateTime(2026, 8, 22, 15, 0),
      category: 'Food & Dining',
      paymentMethod: 'UPI',
      source: 'ocr_receipt',
      items: [
        const ExpenseItemModel(id: 'i010', name: 'Cold Coffee', quantity: 2, price: 180),
        const ExpenseItemModel(id: 'i011', name: 'Sandwich', quantity: 1, price: 200),
      ],
    ),
    // Aug 20
    ExpenseModel(
      id: 'exp_013',
      merchant: 'BMTC Bus',
      amount: 45,
      date: DateTime(2026, 8, 20, 9, 0),
      category: 'Travel',
      paymentMethod: 'UPI',
      source: 'manual',
    ),
    ExpenseModel(
      id: 'exp_014',
      merchant: 'Flipkart',
      amount: 1899,
      date: DateTime(2026, 8, 20, 14, 0),
      category: 'Shopping',
      paymentMethod: 'Debit Card',
      source: 'bank_statement',
    ),
    // Aug 15
    ExpenseModel(
      id: 'exp_015',
      merchant: 'Electricity Board',
      amount: 1450,
      date: DateTime(2026, 8, 15, 0, 0),
      category: 'Bills',
      paymentMethod: 'Net Banking',
      source: 'bank_statement',
      isRecurring: true,
    ),
  ];

  // ─── Analytics ───────────────────────────────────────────────────────────────

  static AnalyticsSummary get analyticsSummary => AnalyticsSummary(
        totalSpending: 24580,
        previousMonthSpending: 22720,
        income: 60000,
        byCategory: [
          const CategorySpending(category: 'Food & Dining', amount: 7200, percentage: 29.3),
          const CategorySpending(category: 'Travel', amount: 4500, percentage: 18.3),
          const CategorySpending(category: 'Shopping', amount: 5800, percentage: 23.6),
          const CategorySpending(category: 'Bills', amount: 3100, percentage: 12.6),
          const CategorySpending(category: 'Health', amount: 1980, percentage: 8.1),
          const CategorySpending(category: 'Entertainment', amount: 2000, percentage: 8.1),
        ],
        monthlyTrend: [
          const MonthlySpending(month: 'Apr', amount: 18900),
          const MonthlySpending(month: 'May', amount: 21400),
          const MonthlySpending(month: 'Jun', amount: 19800),
          const MonthlySpending(month: 'Jul', amount: 23100),
          const MonthlySpending(month: 'Aug', amount: 22720),
          const MonthlySpending(month: 'Sep', amount: 24580),
        ],
        topMerchants: [
          const MerchantSpending(merchant: 'Amazon', amount: 6200, transactionCount: 4, category: 'Shopping'),
          const MerchantSpending(merchant: 'Swiggy', amount: 3800, transactionCount: 6, category: 'Food & Dining'),
          const MerchantSpending(merchant: 'Uber', amount: 2900, transactionCount: 9, category: 'Travel'),
          const MerchantSpending(merchant: 'Zomato', amount: 2100, transactionCount: 3, category: 'Food & Dining'),
          const MerchantSpending(merchant: 'Netflix', amount: 1298, transactionCount: 2, category: 'Entertainment'),
        ],
      );

  // ─── Spending Insights ───────────────────────────────────────────────────────

  static const List<SpendingInsight> insights = [
    SpendingInsight(
      category: 'Food & Dining',
      thisMonth: 7200,
      typicalMin: 5500,
      typicalMax: 6500,
      isUnusual: true,
      description: 'You spent significantly more than usual. 3 restaurant visits contributed ₹3,000.',
    ),
    SpendingInsight(
      category: 'Shopping',
      thisMonth: 5800,
      typicalMin: 4000,
      typicalMax: 6000,
      isUnusual: true,
      description: 'Slightly higher than usual. Amazon purchase of ₹3,499 was the biggest contributor.',
    ),
    SpendingInsight(
      category: 'Travel',
      thisMonth: 4500,
      typicalMin: 3800,
      typicalMax: 5200,
      isUnusual: false,
      description: 'Your spending is within your normal range.',
    ),
    SpendingInsight(
      category: 'Bills',
      thisMonth: 3100,
      typicalMin: 2800,
      typicalMax: 3200,
      isUnusual: false,
      description: 'Utility bills are stable. No unusual charges detected.',
    ),
    SpendingInsight(
      category: 'Health',
      thisMonth: 1980,
      typicalMin: 500,
      typicalMax: 1200,
      isUnusual: true,
      description: 'Significantly higher than usual. Consider reviewing recent pharmacy purchases.',
    ),
    SpendingInsight(
      category: 'Entertainment',
      thisMonth: 2000,
      typicalMin: 800,
      typicalMax: 1200,
      isUnusual: false,
      description: 'Mostly subscription services. No new unusual entertainment spend.',
    ),
  ];

  // ─── Recurring Expenses ───────────────────────────────────────────────────────

  static final List<RecurringExpenseModel> recurringExpenses = [
    RecurringExpenseModel(
      id: 'rec_001',
      merchant: 'Netflix',
      amount: 649,
      category: 'Entertainment',
      interval: 'monthly',
      nextExpected: DateTime(2026, 9, 30),
      emoji: '🎬',
    ),
    RecurringExpenseModel(
      id: 'rec_002',
      merchant: 'Spotify',
      amount: 119,
      category: 'Entertainment',
      interval: 'monthly',
      nextExpected: DateTime(2026, 9, 22),
      emoji: '🎵',
    ),
    RecurringExpenseModel(
      id: 'rec_003',
      merchant: 'Jio Postpaid',
      amount: 799,
      category: 'Bills',
      interval: 'monthly',
      nextExpected: DateTime(2026, 9, 26),
      emoji: '📱',
    ),
    RecurringExpenseModel(
      id: 'rec_004',
      merchant: 'Electricity Board',
      amount: 1450,
      category: 'Bills',
      interval: 'monthly',
      nextExpected: DateTime(2026, 9, 15),
      emoji: '⚡',
    ),
    RecurringExpenseModel(
      id: 'rec_005',
      merchant: 'Society Maintenance',
      amount: 2500,
      category: 'Bills',
      interval: 'monthly',
      nextExpected: DateTime(2026, 9, 5),
      emoji: '🏘️',
    ),
  ];

  // ─── Wishlist ────────────────────────────────────────────────────────────────

  static final List<WishlistItemModel> wishlistItems = [
    WishlistItemModel(
      id: 'wish_001',
      name: 'MacBook Air M3',
      expectedPrice: 114900,
      readiness: 'Possible',
      imageEmoji: '💻',
      analysis: 'Based on your current monthly savings of ₹35,420 and recurring expenses of ₹18,000/month, you could save enough in approximately 4 months. However, your food and shopping spend has been trending upward.',
      addedAt: DateTime(2026, 8, 10),
    ),
    WishlistItemModel(
      id: 'wish_002',
      name: 'Sony WH-1000XM5 Headphones',
      expectedPrice: 24990,
      readiness: 'Comfortable',
      imageEmoji: '🎧',
      analysis: 'This purchase fits comfortably within your budget. You have ₹35,420 remaining this month and this represents less than 75% of your monthly discretionary spend.',
      addedAt: DateTime(2026, 8, 15),
    ),
    WishlistItemModel(
      id: 'wish_003',
      name: 'PlayStation 5',
      expectedPrice: 54990,
      readiness: 'Not Recommended',
      imageEmoji: '🎮',
      analysis: 'Your current spending patterns leave limited room for large discretionary purchases. Your food and health spending has been unusually high this month. We recommend waiting until your spending stabilizes.',
      addedAt: DateTime(2026, 8, 20),
    ),
    WishlistItemModel(
      id: 'wish_004',
      name: 'Kindle Paperwhite',
      expectedPrice: 13999,
      readiness: 'Comfortable',
      imageEmoji: '📖',
      analysis: 'Well within your discretionary budget. This is a small purchase relative to your monthly remaining balance.',
      addedAt: DateTime(2026, 8, 25),
    ),
  ];

  // ─── Splits & Debts ──────────────────────────────────────────────────────────

  static final List<DebtModel> debtsYouOwe = [
    DebtModel(
      id: 'debt_001',
      fromUser: 'Aashi',
      toUser: 'Rahul Sharma',
      amount: 560,
      expenseDescription: 'Dinner at Zomato',
      expenseId: 'exp_009',
      dueDate: DateTime(2026, 9, 10),
    ),
    DebtModel(
      id: 'debt_002',
      fromUser: 'Aashi',
      toUser: 'Priya Singh',
      amount: 325,
      expenseDescription: 'Movie tickets — Cinepolis',
      expenseId: 'exp_016',
      dueDate: DateTime(2026, 9, 8),
    ),
  ];

  static final List<DebtModel> debtsOwedToYou = [
    DebtModel(
      id: 'debt_003',
      fromUser: 'Aman Verma',
      toUser: 'Aashi',
      amount: 700,
      expenseDescription: 'Weekend trip groceries',
      expenseId: 'exp_017',
      dueDate: DateTime(2026, 9, 12),
    ),
    DebtModel(
      id: 'debt_004',
      fromUser: 'Neha Kapoor',
      toUser: 'Aashi',
      amount: 480,
      expenseDescription: 'Cafe Coffee Day hangout',
      expenseId: 'exp_012',
      dueDate: DateTime(2026, 9, 15),
    ),
  ];

  // ─── Chat responses for Ask Expenses ─────────────────────────────────────────

  static Map<String, String> get chatResponses => {
        'food': 'You spent **₹7,200** on food this month (Sep 2026). That\'s across 8 transactions — Swiggy (₹3,800), Restaurant ABC (₹1,250), Zomato (₹1,120), and Cafe Coffee Day (₹560) were your top food merchants.',
        'this month': 'Your total spending in September 2026 is **₹24,580** so far. You\'ve spent the most on Shopping (₹5,800), followed by Food & Dining (₹7,200) and Travel (₹4,500).',
        'recurring': 'Your recurring expenses total approximately **₹5,517/month**: Netflix (₹649), Spotify (₹119), Jio Postpaid (₹799), Electricity Board (₹1,450), and Society Maintenance (₹2,500).',
        'owe': 'Rahul Sharma owes you... wait, actually, you owe Rahul **₹560** for dinner at Zomato and Priya **₹325** for movie tickets. In total, you owe **₹885**.',
        'owes me': 'Aman Verma owes you **₹700** (weekend trip groceries) and Neha Kapoor owes you **₹480** (Cafe Coffee Day). Total owed to you: **₹1,180**.',
        'travel': 'You spent **₹4,500** on travel this month. Uber was your most used service (₹2,900 across 9 rides), followed by Rapido (₹180) and BMTC bus (₹45).',
        'amazon': 'You\'ve spent **₹6,200** on Amazon across 4 transactions this month. The biggest was a ₹3,499 purchase on Aug 28.',
        'shopping': 'Your shopping spend this month is **₹5,800** — Amazon (₹3,499), D-Mart (₹2,340), and Flipkart (₹1,899) were your top shopping merchants.',
        'save': 'Based on your income of ₹60,000 and spending of ₹24,580, you\'ve saved **₹35,420** this month. That\'s 59% of your income — well above the recommended 20% savings rate!',
        'bills': 'Your bills and utilities this month total **₹3,100**: Electricity Board (₹1,450), Jio Postpaid (₹799), and Society Maintenance (₹2,500 for Aug).',
      };

  static String getSmartResponse(String query) {
    final q = query.toLowerCase();
    for (final key in chatResponses.keys) {
      if (q.contains(key)) return chatResponses[key]!;
    }
    return 'I found **${expenses.where((e) => e.merchant.toLowerCase().contains(q) || e.category.toLowerCase().contains(q)).length}** matching transactions. Try asking about a specific category like "food", "travel", or "shopping", or ask about your total spend, recurring expenses, or who owes you money.';
  }
}
