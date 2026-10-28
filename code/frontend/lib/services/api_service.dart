import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense_model.dart';
import '../models/analytics_model.dart';
import '../models/wishlist_model.dart';
import '../models/split_model.dart';
import '../models/notification_model.dart';
import '../models/intelligence_model.dart';
import '../models/ai_model.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';

class ApiService {
  static const String baseUrl = 'http://172.16.213.72:8000';
  static const String _tokenKey = 'jwt_token';

  // ─── Token Management ────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<Map<String, String>> _authHeaders({bool jsonContent = false}) async {
    final token = await getToken();
    final headers = <String, String>{};
    if (jsonContent) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ─── Authentication ──────────────────────────────────────────────────────────

  static Future<void> login(String email, String password) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await saveToken(data['access_token']);
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  static Future<void> register(String name, String email, String password) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      await saveToken(data['access_token']);
    } else {
      throw Exception('Registration failed: ${response.body}');
    }
  }

  static Future<UserModel> getCurrentUser() async {
    final uri = Uri.parse('$baseUrl/auth/me');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return UserModel.fromJson(data);
    } else {
      throw Exception('Failed to fetch user profile: ${response.body}');
    }
  }

  // ─── Document Uploads ────────────────────────────────────────────────────────

  static Future<String> uploadDocument(String filePath) async {
    final uri = Uri.parse('$baseUrl/documents/upload');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    request.fields['document_type'] = 'receipt';

    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    debugPrint('Uploading document to $uri...');
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['id'] as String;
    } else {
      debugPrint('Upload failed: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to upload document');
    }
  }

  static Future<Map<String, dynamic>> processDocument(String documentId) async {
    final uri = Uri.parse('$baseUrl/documents/$documentId/process');
    final headers = await _authHeaders();
    final response = await http.post(uri, headers: headers);

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to process document');
    }
  }

  // ─── Transactions CRUD ────────────────────────────────────────────────────────

  static Future<List<ExpenseModel>> getTransactions({int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/transactions/?limit=$limit');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => ExpenseModel.fromJsonBackend(item)).toList();
    } else {
      throw Exception('Failed to load transactions: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> txData) async {
    final uri = Uri.parse('$baseUrl/transactions/');
    final headers = await _authHeaders(jsonContent: true);
    final response = await http.post(uri, headers: headers, body: json.encode(txData));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create transaction: ${response.body}');
    }
  }

  static Future<void> deleteTransaction(String transactionId) async {
    final uri = Uri.parse('$baseUrl/transactions/$transactionId');
    final headers = await _authHeaders();
    final response = await http.delete(uri, headers: headers);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete transaction: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> updateTransaction(
    String transactionId,
    Map<String, dynamic> txData,
  ) async {
    final uri = Uri.parse('$baseUrl/transactions/$transactionId');
    final headers = await _authHeaders(jsonContent: true);
    final response = await http.put(uri, headers: headers, body: json.encode(txData));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update transaction: ${response.body}');
    }
  }

  // ─── Categories ─────────────────────────────────────────────────────────────

  static Future<List<CategoryModel>> getCategories() async {
    final uri = Uri.parse('$baseUrl/categories/');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => CategoryModel.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load categories: ${response.body}');
    }
  }

  static Future<void> seedCategories() async {
    final uri = Uri.parse('$baseUrl/categories/seed');
    final headers = await _authHeaders();
    await http.post(uri, headers: headers);
  }

  // ─── Analytics ───────────────────────────────────────────────────────────────

  static Future<AnalyticsSummary> getAnalyticsSummary() async {
    final uri = Uri.parse('$baseUrl/analytics/summary');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AnalyticsSummary.fromJsonBackend(data);
    } else {
      throw Exception('Failed to load analytics: ${response.body}');
    }
  }

  // ─── Bank Statements ──────────────────────────────────────────────────────────

  /// Uploads a bank statement (PDF or CSV) and returns the statement ID.
  static Future<String> uploadBankStatement(String filePath) async {
    final uri = Uri.parse('$baseUrl/bank-statements/upload');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return data['id'] as String;
    } else {
      throw Exception('Upload failed: ${response.body}');
    }
  }

  /// Triggers parsing of the uploaded statement and returns parsed detail JSON.
  static Future<Map<String, dynamic>> parseBankStatement(
      String statementId) async {
    final uri =
        Uri.parse('$baseUrl/bank-statements/$statementId/parse');
    final token = await getToken();

    final response = await http.post(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Parsing failed: ${response.body}');
    }
  }

  /// Lists all bank statement summaries for the current user.
  static Future<List<Map<String, dynamic>>> listBankStatements() async {
    final uri = Uri.parse('$baseUrl/bank-statements/');
    final token = await getToken();

    final response = await http.get(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load statements: ${response.body}');
    }
  }

  /// Returns full detail (including parsed rows) for a single statement.
  static Future<Map<String, dynamic>> getBankStatement(
      String statementId) async {
    final uri = Uri.parse('$baseUrl/bank-statements/$statementId');
    final token = await getToken();

    final response = await http.get(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load statement: ${response.body}');
    }
  }

  /// Deletes a bank statement.
  static Future<void> deleteBankStatement(String statementId) async {
    final uri = Uri.parse('$baseUrl/bank-statements/$statementId');
    final token = await getToken();

    final response = await http.delete(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Delete failed: ${response.body}');
    }
  }

  static Future<List<CategorySpending>> getCategoryWiseSpending({int? month, int? year}) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final uri = Uri.parse('$baseUrl/analytics/categories').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => CategorySpending.fromJsonBackend(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load category spending');
    }
  }

  static Future<List<MerchantSpending>> getMerchantWiseSpending({int limit = 10}) async {
    final uri = Uri.parse('$baseUrl/analytics/merchants?limit=$limit');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => MerchantSpending.fromJsonBackend(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load merchant spending');
    }
  }

  static Future<List<ItemSpendingSummary>> getItemWiseSpending({int limit = 20}) async {
    final uri = Uri.parse('$baseUrl/analytics/items?limit=$limit');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => ItemSpendingSummary.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load item spending');
    }
  }

  static Future<List<SpendingTrend>> getSpendingTrends({int months = 6}) async {
    final uri = Uri.parse('$baseUrl/analytics/trends?months=$months');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => SpendingTrend.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load spending trends');
    }
  }

  static Future<MonthlyComparison> compareMonthlySpending({
    int? currentMonth,
    int? currentYear,
    int? prevMonth,
    int? prevYear,
  }) async {
    final queryParams = <String, String>{};
    if (currentMonth != null) queryParams['current_month'] = currentMonth.toString();
    if (currentYear != null) queryParams['current_year'] = currentYear.toString();
    if (prevMonth != null) queryParams['prev_month'] = prevMonth.toString();
    if (prevYear != null) queryParams['prev_year'] = prevYear.toString();

    final uri = Uri.parse('$baseUrl/analytics/compare').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return MonthlyComparison.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to compare monthly spending');
    }
  }

  static Future<SpendingSummaryResponse> generateSpendingSummary({int? month, int? year}) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final uri = Uri.parse('$baseUrl/analytics/summary-text').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return SpendingSummaryResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to generate spending summary');
    }
  }

  // ─── Wishlist ────────────────────────────────────────────────────────────────

  static Future<List<WishlistItemModel>> getWishlistItems() async {
    final uri = Uri.parse('$baseUrl/wishlist/');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => WishlistItemModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load wishlist items');
    }
  }

  static Future<WishlistItemModel> addWishlistItem({
    required String name,
    required double expectedPrice,
    String priority = 'medium',
    String? description,
    String? url,
  }) async {
    final uri = Uri.parse('$baseUrl/wishlist/');
    final headers = await _authHeaders(jsonContent: true);
    final body = {
      'name': name,
      'expected_price': expectedPrice,
      'priority': priority,
      if (description != null && description.isNotEmpty) 'description': description,
      if (url != null && url.isNotEmpty) 'url': url,
    };

    final response = await http.post(uri, headers: headers, body: json.encode(body));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return WishlistItemModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to add wishlist item: ${response.body}');
    }
  }

  static Future<void> deleteWishlistItem(String itemId) async {
    final uri = Uri.parse('$baseUrl/wishlist/$itemId');
    final headers = await _authHeaders();
    final response = await http.delete(uri, headers: headers);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete wishlist item');
    }
  }

  static Future<DiscretionaryBudgetModel> calculateDiscretionaryBudget() async {
    final uri = Uri.parse('$baseUrl/wishlist/budget');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return DiscretionaryBudgetModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to calculate discretionary budget');
    }
  }

  static Future<ReadinessResponseModel> calculatePurchaseReadiness(String itemId) async {
    final uri = Uri.parse('$baseUrl/wishlist/$itemId/readiness');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return ReadinessResponseModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to calculate purchase readiness');
    }
  }

  // ─── Notifications ───────────────────────────────────────────────────────────

  static Future<List<NotificationItemModel>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/notifications/?unread_only=$unreadOnly&limit=$limit');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => NotificationItemModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  static Future<int> getUnreadNotificationCount() async {
    final uri = Uri.parse('$baseUrl/notifications/unread-count');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['unread_count'] as int? ?? 0;
    } else {
      return 0;
    }
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    final uri = Uri.parse('$baseUrl/notifications/$notificationId/read');
    final headers = await _authHeaders();
    final response = await http.post(uri, headers: headers);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  static Future<void> markAllNotificationsAsRead() async {
    final uri = Uri.parse('$baseUrl/notifications/read-all');
    final headers = await _authHeaders();
    final response = await http.post(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to mark all notifications as read');
    }
  }

  static Future<AutoNotificationResult> triggerAutoNotifications() async {
    final uri = Uri.parse('$baseUrl/notifications/trigger-auto');
    final headers = await _authHeaders();
    final response = await http.post(uri, headers: headers);

    if (response.statusCode == 200) {
      return AutoNotificationResult.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to trigger auto notifications');
    }
  }

  // ─── Friends & Contacts ───────────────────────────────────────────────────────

  static Future<List<FriendModel>> getFriends() async {
    final uri = Uri.parse('$baseUrl/friends/');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => FriendModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load friends');
    }
  }

  static Future<FriendModel> addFriend(String name, {String? email, String? phone}) async {
    final uri = Uri.parse('$baseUrl/friends/');
    final headers = await _authHeaders(jsonContent: true);
    final body = {
      'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };

    final response = await http.post(uri, headers: headers, body: json.encode(body));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return FriendModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to add friend: ${response.body}');
    }
  }

  static Future<void> deleteFriend(String friendId) async {
    final uri = Uri.parse('$baseUrl/friends/$friendId');
    final headers = await _authHeaders();
    final response = await http.delete(uri, headers: headers);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete friend');
    }
  }

  static Future<FriendLedgerModel> getFriendLedger(String friendId) async {
    final uri = Uri.parse('$baseUrl/friends/$friendId/ledger');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return FriendLedgerModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load friend ledger');
    }
  }

  // ─── Expense Splitting & Settlements ─────────────────────────────────────────

  static Future<UserBalanceModel> calculateUserBalance() async {
    final uri = Uri.parse('$baseUrl/splits/balances');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return UserBalanceModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to calculate user balance');
    }
  }

  static Future<List<SplitItemModel>> getExpenseSplits() async {
    final uri = Uri.parse('$baseUrl/splits/');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => SplitItemModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load splits');
    }
  }

  static Future<SplitItemModel> createExpenseSplit({
    required String title,
    required double totalAmount,
    String splitType = 'equal',
    String? description,
    required List<Map<String, dynamic>> participants,
  }) async {
    final uri = Uri.parse('$baseUrl/splits/');
    final headers = await _authHeaders(jsonContent: true);
    final body = {
      'title': title,
      'total_amount': totalAmount,
      'currency': 'INR',
      'split_type': splitType,
      if (description != null && description.isNotEmpty) 'description': description,
      'participants': participants,
    };

    final response = await http.post(uri, headers: headers, body: json.encode(body));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return SplitItemModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create split: ${response.body}');
    }
  }

  static Future<List<SettlementItemModel>> getSettlementHistory({String? friendName}) async {
    final queryParams = <String, String>{};
    if (friendName != null && friendName.isNotEmpty) {
      queryParams['friend_name'] = friendName;
    }
    final uri = Uri.parse('$baseUrl/splits/settlements').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => SettlementItemModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load settlement history');
    }
  }

  static Future<SettlementItemModel> recordSettlement({
    String? splitId,
    required String payerName,
    required String payeeName,
    required double amount,
  }) async {
    final uri = Uri.parse('$baseUrl/splits/settlements');
    final headers = await _authHeaders(jsonContent: true);
    final body = <String, dynamic>{
      'payer_name': payerName,
      'payee_name': payeeName,
      'amount': amount,
    };
    if (splitId != null) {
      body['split_id'] = splitId;
    }

    final response = await http.post(uri, headers: headers, body: json.encode(body));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return SettlementItemModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to record settlement: ${response.body}');
    }
  }

  // ─── Financial Intelligence ──────────────────────────────────────────────────

  static Future<List<String>> detectUnusualSpending() async {
    final uri = Uri.parse('$baseUrl/intelligence/unusual-spending');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => item.toString()).toList();
    } else {
      throw Exception('Failed to detect unusual spending');
    }
  }

  static Future<List<DetectedRecurringModel>> detectRecurringExpenses() async {
    final uri = Uri.parse('$baseUrl/intelligence/recurring');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => DetectedRecurringModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to detect recurring expenses');
    }
  }

  static Future<List<SubscriptionResponseModel>> detectSubscriptions() async {
    final uri = Uri.parse('$baseUrl/intelligence/subscriptions');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => SubscriptionResponseModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to detect subscriptions');
    }
  }

  // ─── AI Queries ──────────────────────────────────────────────────────────────

  static Future<NLQueryResponseModel> naturalLanguageQuery(String question) async {
    final uri = Uri.parse('$baseUrl/ai/query');
    final headers = await _authHeaders(jsonContent: true);
    final response = await http.post(
      uri,
      headers: headers,
      body: json.encode({'question': question}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return NLQueryResponseModel.fromJson(data);
    } else {
      throw Exception('Failed to process AI query: ${response.body}');
    }
  }
}

