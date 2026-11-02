import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'local_notification_service.dart';


/// Cache container with timestamp and TTL support.
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

_CacheEntry(this.data, this.ttl) : timestamp = DateTime.now();

  bool get isValid => DateTime.now().difference(timestamp) < ttl;
}

class ApiService {
  // static const String baseUrl = String.fromEnvironment(
  //   'API_BASE_URL',
  //   defaultValue: 'http://172.16.216.51:8000',
  // );
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://expense-tracker-gv07.onrender.com',
  );
  static const String _tokenKey = 'jwt_token';
  static const Duration _defaultTimeout = Duration(seconds: 15);

  /// Shared persistent HTTP client for connection pooling and TCP reuse.
  @visibleForTesting
  static http.Client client = http.Client();
  static http.Client get _client => client;

  /// In-memory token cache to avoid recurrent disk/channel lookups.
  static String? _cachedToken;

  /// Cache storage for GET endpoints.
  static final Map<String, _CacheEntry<dynamic>> _cache = {};

  /// In-flight request deduplication map to prevent duplicate concurrent network requests.
  static final Map<String, Future<dynamic>> _inFlightRequests = {};

  // ─── Global State Notification ───────────────────────────────────────────────
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  static void notifyDataChanged() {
    // Invalidate caches immediately
    invalidateCache('transactions');
    invalidateCache('analytics');
    invalidateCache('intelligence');
    invalidateCache('budgets');
    invalidateCache('wishlist');
    invalidateCache('notifications');
    invalidateCache('splits');
    invalidateCache('friends');
    invalidateCache('user');
    refreshNotifier.value++;
  }

  /// Invalidate cache entries by key prefix, or entire cache if prefix is null.
  static void invalidateCache([String? prefix]) {
    if (prefix == null) {
      _cache.clear();
    } else {
      _cache.removeWhere((key, _) => key.startsWith(prefix));
    }
  }

  /// Internal caching and request deduplication runner.
  static Future<T> _fetchWithCache<T>({
    required String key,
    required Duration ttl,
    required Future<T> Function() fetcher,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final entry = _cache[key];
      if (entry != null && entry.isValid && entry.data is T) {
        return entry.data as T;
      }
    }

    if (_inFlightRequests.containsKey(key)) {
      return await _inFlightRequests[key] as T;
    }

    final future = fetcher();
    _inFlightRequests[key] = future;

    try {
      final result = await future;
      _cache[key] = _CacheEntry<T>(result, ttl);
      return result;
    } finally {
      _inFlightRequests.remove(key);
    }
  }

  /// Retry transient errors with exponential backoff for idempotent operations.
  static Future<http.Response> _getWithRetry(
    Uri uri,
    Map<String, String> headers, {
    int retries = 2,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final res = await _client
            .get(uri, headers: headers)
            .timeout(_defaultTimeout);
        return res;
      } catch (e) {
        attempt++;
        if (attempt > retries ||
            e is! SocketException && e is! TimeoutException) {
          rethrow;
        }
        await Future.delayed(
          Duration(milliseconds: 200 * (1 << (attempt - 1))),
        );
      }
    }
  }

  // ─── Token Management ────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<Map<String, String>> _authHeaders({
    bool jsonContent = false,
  }) async {
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
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': email, 'password': password}),
        )
        .timeout(_defaultTimeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await saveToken(data['access_token']);
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  static Future<void> register(
    String name,
    String email,
    String password,
  ) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'name': name,
            'email': email,
            'password': password,
          }),
        )
        .timeout(_defaultTimeout);

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      await saveToken(data['access_token']);
    } else {
      throw Exception('Registration failed: ${response.body}');
    }
  }

  static Future<UserModel> getCurrentUser({bool forceRefresh = false}) async {
    return _fetchWithCache<UserModel>(
      key: 'user:me',
      ttl: const Duration(minutes: 5),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/auth/me');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return UserModel.fromJson(data);
        } else {
          throw Exception('Failed to fetch user profile: ${response.body}');
        }
      },
    );
  }

  static Future<UserModel> updateProfile({
    String? name,
    String? email,
    double? monthlyIncome,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/me');
    final headers = await _authHeaders(jsonContent: true);
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (monthlyIncome != null) body['monthly_income'] = monthlyIncome;

    final response = await _client
        .patch(
          uri,
          headers: headers,
          body: json.encode(body),
        )
        .timeout(_defaultTimeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
            notifyDataChanged();
      return UserModel.fromJson(data);
    } else {
      throw Exception('Failed to update profile: ${response.body}');
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
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['id']?.toString() ?? '';
    } else {
      debugPrint('Upload failed: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to upload document');
    }
  }

  static Future<Map<String, dynamic>> processDocument(String documentId) async {
    final uri = Uri.parse('$baseUrl/documents/$documentId/process');
    final headers = await _authHeaders();
    final response = await _client
        .post(uri, headers: headers)
        .timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to process document');
    }
  }

  static Future<void> deleteDocument(String documentId) async {
    final uri = Uri.parse('$baseUrl/documents/$documentId');
    final headers = await _authHeaders();
    final response = await _client
        .delete(uri, headers: headers)
        .timeout(_defaultTimeout);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete document: ${response.body}');
    }
  }

  // ─── Transactions CRUD ────────────────────────────────────────────────────────

  static Future<List<ExpenseModel>> getTransactions({
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<ExpenseModel>>(
      key: 'transactions:list:limit=$limit',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/transactions/?limit=$limit');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map((item) => ExpenseModel.fromJsonBackend(item))
              .toList();
        } else {
          throw Exception('Failed to load transactions: ${response.body}');
        }
      },
    );
  }

  static Future<Map<String, dynamic>> createTransaction(
    Map<String, dynamic> txData, {
    bool notify = true,
  }) async {
    final uri = Uri.parse('$baseUrl/transactions/');
    final headers = await _authHeaders(jsonContent: true);
    final response = await _client
        .post(uri, headers: headers, body: json.encode(txData))
        .timeout(_defaultTimeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      if (notify) {
        notifyDataChanged();
        try {
          final merchant = txData['merchant_name']?.toString() ?? 'Merchant';
          final amt = (txData['amount'] is num)
              ? (txData['amount'] as num).toDouble()
              : double.tryParse(txData['amount']?.toString() ?? '0') ?? 0.0;
          if (amt > 0) {
            LocalNotificationService.showExpenseCapturedAlert(
              merchant: merchant,
              amount: amt,
            );
          }
        } catch (_) {}
      }
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create transaction: ${response.body}');
    }
  }

  static Future<List<dynamic>> createBulkTransactions(
    List<Map<String, dynamic>> txList, {
    bool notify = true,
  }) async {
    final uri = Uri.parse('$baseUrl/transactions/bulk');
    final headers = await _authHeaders(jsonContent: true);
    final response = await _client
        .post(uri, headers: headers, body: json.encode(txList))
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 201 || response.statusCode == 200) {
      if (notify) {
        notifyDataChanged();
      }
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to create bulk transactions: ${response.body}');
    }
  }

  static Future<void> deleteTransaction(String transactionId) async {
    final uri = Uri.parse('$baseUrl/transactions/$transactionId');
    final headers = await _authHeaders();
    final response = await _client
        .delete(uri, headers: headers)
        .timeout(_defaultTimeout);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete transaction: ${response.body}');
    }
    notifyDataChanged();
  }

  static Future<Map<String, dynamic>> updateTransaction(
    String transactionId,
    Map<String, dynamic> txData,
  ) async {
    final uri = Uri.parse('$baseUrl/transactions/$transactionId');
    final headers = await _authHeaders(jsonContent: true);
    final response = await _client
        .put(uri, headers: headers, body: json.encode(txData))
        .timeout(_defaultTimeout);

    if (response.statusCode == 200) {
      notifyDataChanged();
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update transaction: ${response.body}');
    }
  }

  // ─── Categories ─────────────────────────────────────────────────────────────

  static Future<List<CategoryModel>> getCategories({
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<CategoryModel>>(
      key: 'categories:all',
      ttl: const Duration(minutes: 10),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/categories/');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((item) => CategoryModel.fromJson(item)).toList();
        } else {
          throw Exception('Failed to load categories: ${response.body}');
        }
      },
    );
  }

  static Future<void> seedCategories() async {
    final uri = Uri.parse('$baseUrl/categories/seed');
    final headers = await _authHeaders();
    await _client.post(uri, headers: headers).timeout(_defaultTimeout);
    invalidateCache('categories');
  }

  // ─── Analytics ───────────────────────────────────────────────────────────────

  static Future<AnalyticsSummary> getAnalyticsSummary({
    int? month,
    int? year,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final cacheKey = 'analytics:summary:m=${month ?? 0}:y=${year ?? 0}';
    return _fetchWithCache<AnalyticsSummary>(
      key: cacheKey,
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/analytics/summary')
            .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return AnalyticsSummary.fromJsonBackend(data);
        } else {
          throw Exception('Failed to load analytics: ${response.body}');
        }
      },
    );
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

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      invalidateCache('bank_statements');
      return data['id']?.toString() ?? '';
    } else {
      throw Exception('Upload failed: ${response.body}');
    }
  }

  /// Triggers parsing of the uploaded statement and returns parsed detail JSON.
  static Future<Map<String, dynamic>> parseBankStatement(
    String statementId,
  ) async {
    final uri = Uri.parse('$baseUrl/bank-statements/$statementId/parse');
    final token = await getToken();

    try {
      final response = await _client
          .post(
            uri,
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        invalidateCache('bank_statements');
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Parsing failed: ${response.body}');
      }
    } catch (e) {
      // If client timed out or connection dropped, check if statement is already parsed on backend
      try {
        final detail = await getBankStatement(statementId, forceRefresh: true);
        if (detail['status'] == 'parsed' && detail['parsed_rows'] != null) {
          invalidateCache('bank_statements');
          return detail;
        }
      } catch (_) {}
      rethrow;
    }
  }

  /// Lists all bank statement summaries for the current user.
  static Future<List<Map<String, dynamic>>> listBankStatements({
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<Map<String, dynamic>>>(
      key: 'bank_statements:list',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/bank-statements/');
        final token = await getToken();

        final response = await _getWithRetry(uri, {
          if (token != null) 'Authorization': 'Bearer $token',
        });

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((item) => item as Map<String, dynamic>).toList();
        } else {
          throw Exception('Failed to load statements: ${response.body}');
        }
      },
    );
  }

  /// Returns full detail (including parsed rows) for a single statement.
  static Future<Map<String, dynamic>> getBankStatement(
    String statementId, {
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<Map<String, dynamic>>(
      key: 'bank_statements:detail:$statementId',
      ttl: const Duration(minutes: 1),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/bank-statements/$statementId');
        final token = await getToken();

        final response = await _getWithRetry(uri, {
          if (token != null) 'Authorization': 'Bearer $token',
        });

        if (response.statusCode == 200) {
          return json.decode(response.body) as Map<String, dynamic>;
        } else {
          throw Exception('Failed to load statement: ${response.body}');
        }
      },
    );
  }

  /// Deletes a bank statement.
  static Future<void> deleteBankStatement(String statementId) async {
    final uri = Uri.parse('$baseUrl/bank-statements/$statementId');
    final token = await getToken();

    final response = await _client
        .delete(
          uri,
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        )
        .timeout(_defaultTimeout);

    if (response.statusCode != 204) {
      throw Exception('Delete failed: ${response.body}');
    }
    invalidateCache('bank_statements');
  }

  /// Merges verified entries from a bank statement into confirmed transactions.
  static Future<Map<String, dynamic>> mergeBankStatement(
    String statementId, {
    List<int>? selectedIndices,
  }) async {
    final uri = Uri.parse('$baseUrl/bank-statements/$statementId/merge');
    final headers = await _authHeaders(jsonContent: true);
    final body = json.encode({
      if (selectedIndices != null) 'selected_indices': selectedIndices,
    });

    final response = await _client
        .post(uri, headers: headers, body: body)
        .timeout(_defaultTimeout);
    if (response.statusCode == 200) {
      notifyDataChanged();
      invalidateCache('bank_statements');
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to merge statement: ${response.body}');
    }
  }

  // ─── Budgets ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getBudget({
    int? month,
    int? year,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final m = month ?? now.month;
    final y = year ?? now.year;
    final monthStr = '$y-${m.toString().padLeft(2, '0')}';
    return _fetchWithCache<Map<String, dynamic>?>(
      key: 'budgets:month=$monthStr',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/budgets/available?month=$monthStr');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);
        if (response.statusCode == 200) {
          final dynamic decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          } else if (decoded is List && decoded.isNotEmpty) {
            return decoded.first as Map<String, dynamic>;
          }
        }
        return null;
      },
    );
  }

  static Future<Map<String, dynamic>> setBudget({
    required int month,
    required int year,
    required double spendingLimit,
    required double savingsGoal,
  }) async {
    final uri = Uri.parse('$baseUrl/budgets/');
    final headers = await _authHeaders(jsonContent: true);
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final body = json.encode({
      'month': monthStr,
      'spending_limit': spendingLimit,
      'savings_goal': savingsGoal,
    });
    final response = await _client
        .post(uri, headers: headers, body: body)
        .timeout(_defaultTimeout);
    if (response.statusCode == 200 || response.statusCode == 201) {
      notifyDataChanged();
      invalidateCache('budgets');
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to save budget: ${response.body}');
    }
  }

  static Future<List<CategorySpending>> getCategoryWiseSpending({
    int? month,
    int? year,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final cacheKey = 'analytics:categories:m=${month ?? 0}:y=${year ?? 0}';
    return _fetchWithCache<List<CategorySpending>>(
      key: cacheKey,
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/analytics/categories')
            .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map(
                (item) => CategorySpending.fromJsonBackend(
                  item as Map<String, dynamic>,
                ),
              )
              .toList();
        } else {
          throw Exception('Failed to load category spending');
        }
      },
    );
  }

  static Future<List<MerchantSpending>> getMerchantWiseSpending({
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<MerchantSpending>>(
      key: 'analytics:merchants:limit=$limit',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/analytics/merchants?limit=$limit');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map(
                (item) => MerchantSpending.fromJsonBackend(
                  item as Map<String, dynamic>,
                ),
              )
              .toList();
        } else {
          throw Exception('Failed to load merchant spending');
        }
      },
    );
  }

  static Future<List<ItemSpendingSummary>> getItemWiseSpending({
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<ItemSpendingSummary>>(
      key: 'analytics:items:limit=$limit',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/analytics/items?limit=$limit');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map(
                (item) =>
                    ItemSpendingSummary.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        } else {
          throw Exception('Failed to load item spending');
        }
      },
    );
  }

  static Future<List<SpendingTrend>> getSpendingTrends({
    int months = 6,
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<SpendingTrend>>(
      key: 'analytics:trends:months=$months',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/analytics/trends?months=$months');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map(
                (item) => SpendingTrend.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        } else {
          throw Exception('Failed to load spending trends');
        }
      },
    );
  }

  static Future<MonthlyComparison> compareMonthlySpending({
    int? currentMonth,
    int? currentYear,
    int? prevMonth,
    int? prevYear,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{};
    if (currentMonth != null)
      queryParams['current_month'] = currentMonth.toString();
    if (currentYear != null)
      queryParams['current_year'] = currentYear.toString();
    if (prevMonth != null) queryParams['prev_month'] = prevMonth.toString();
    if (prevYear != null) queryParams['prev_year'] = prevYear.toString();

    final key = 'analytics:compare:$queryParams';
    return _fetchWithCache<MonthlyComparison>(
      key: key,
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/analytics/compare')
            .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          return MonthlyComparison.fromJson(json.decode(response.body));
        } else {
          throw Exception('Failed to compare monthly spending');
        }
      },
    );
  }

  static Future<SpendingSummaryResponse> generateSpendingSummary({
    int? month,
    int? year,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final key = 'analytics:summary_text:$queryParams';
    return _fetchWithCache<SpendingSummaryResponse>(
      key: key,
      ttl: const Duration(minutes: 2),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/analytics/summary-text')
            .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          return SpendingSummaryResponse.fromJson(json.decode(response.body));
        } else {
          throw Exception('Failed to generate spending summary');
        }
      },
    );
  }

  // ─── Wishlist ────────────────────────────────────────────────────────────────

  static Future<List<WishlistItemModel>> getWishlistItems({
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<WishlistItemModel>>(
      key: 'wishlist:items',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/wishlist/');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map(
                (item) =>
                    WishlistItemModel.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        } else {
          throw Exception('Failed to load wishlist items');
        }
      },
    );
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
      if (description != null && description.isNotEmpty)
        'description': description,
      if (url != null && url.isNotEmpty) 'url': url,
    };

    final response = await _client
        .post(uri, headers: headers, body: json.encode(body))
        .timeout(_defaultTimeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      notifyDataChanged();
      invalidateCache('wishlist');
      return WishlistItemModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to add wishlist item: ${response.body}');
    }
  }

  static Future<void> deleteWishlistItem(String itemId) async {
    final uri = Uri.parse('$baseUrl/wishlist/$itemId');
    final headers = await _authHeaders();
    final response = await _client
        .delete(uri, headers: headers)
        .timeout(_defaultTimeout);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete wishlist item');
    }
    notifyDataChanged();
    invalidateCache('wishlist');
  }

  static Future<DiscretionaryBudgetModel> calculateDiscretionaryBudget({
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<DiscretionaryBudgetModel>(
      key: 'wishlist:budget',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/wishlist/budget');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          return DiscretionaryBudgetModel.fromJson(json.decode(response.body));
        } else {
          throw Exception('Failed to calculate discretionary budget');
        }
      },
    );
  }

  static Future<ReadinessResponseModel> calculatePurchaseReadiness(
    String itemId, {
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<ReadinessResponseModel>(
      key: 'wishlist:readiness:$itemId',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/wishlist/$itemId/readiness');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          return ReadinessResponseModel.fromJson(json.decode(response.body));
        } else {
          throw Exception('Failed to calculate purchase readiness');
        }
      },
    );
  }

  // ─── Notifications ───────────────────────────────────────────────────────────

  static Future<List<NotificationItemModel>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<NotificationItemModel>>(
      key: 'notifications:list:unread=$unreadOnly:limit=$limit',
      ttl: const Duration(seconds: 15),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse(
          '$baseUrl/notifications/?unread_only=$unreadOnly&limit=$limit',
        );
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map(
                (item) => NotificationItemModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList();
        } else {
          throw Exception('Failed to load notifications');
        }
      },
    );
  }

  static Future<int> getUnreadNotificationCount({
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<int>(
      key: 'notifications:unread_count',
      ttl: const Duration(seconds: 15),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/notifications/unread-count');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['unread_count'] as int? ?? 0;
        } else {
          return 0;
        }
      },
    );
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    final uri = Uri.parse('$baseUrl/notifications/$notificationId/read');
    final headers = await _authHeaders();
    final response = await _client
        .post(uri, headers: headers)
        .timeout(_defaultTimeout);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
    invalidateCache('notifications');
    notifyDataChanged();
  }

  static Future<void> markAllNotificationsAsRead() async {
    final uri = Uri.parse('$baseUrl/notifications/read-all');
    final headers = await _authHeaders();
    final response = await _client
        .post(uri, headers: headers)
        .timeout(_defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to mark all notifications as read');
    }
    invalidateCache('notifications');
    notifyDataChanged();
  }

  static DateTime? _lastAutoNotifScan;

  static Future<AutoNotificationResult> triggerAutoNotifications({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastAutoNotifScan != null &&
        now.difference(_lastAutoNotifScan!) < const Duration(minutes: 5)) {
      return AutoNotificationResult(generatedCount: 0, notifications: []);
    }
    _lastAutoNotifScan = now;
    final uri = Uri.parse('$baseUrl/notifications/trigger-auto');
    final headers = await _authHeaders();
    final response = await _client
        .post(uri, headers: headers)
        .timeout(_defaultTimeout);

    if (response.statusCode == 200) {
      invalidateCache('notifications');
      return AutoNotificationResult.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to trigger auto notifications');
    }
  }

  // ─── Friends & Contacts ───────────────────────────────────────────────────────

  static Future<List<FriendModel>> getFriends({
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<FriendModel>>(
      key: 'friends:all',
      ttl: const Duration(minutes: 1),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/friends/');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map((item) => FriendModel.fromJson(item as Map<String, dynamic>))
              .toList();
        } else {
          throw Exception('Failed to load friends');
        }
      },
    );
  }

  static Future<FriendModel> addFriend(
    String name, {
    String? email,
    String? phone,
  }) async {
    final uri = Uri.parse('$baseUrl/friends/');
    final headers = await _authHeaders(jsonContent: true);
    final body = {
      'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };

    final response = await _client
        .post(uri, headers: headers, body: json.encode(body))
        .timeout(_defaultTimeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      invalidateCache('friends');
      return FriendModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to add friend: ${response.body}');
    }
  }

  static Future<void> deleteFriend(String friendId) async {
    final uri = Uri.parse('$baseUrl/friends/$friendId');
    final headers = await _authHeaders();
    final response = await _client
        .delete(uri, headers: headers)
        .timeout(_defaultTimeout);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete friend');
    }
    invalidateCache('friends');
  }

  static Future<FriendLedgerModel> getFriendLedger(
    String friendId, {
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<FriendLedgerModel>(
      key: 'friends:ledger:$friendId',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/friends/$friendId/ledger');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          return FriendLedgerModel.fromJson(json.decode(response.body));
        } else {
          throw Exception('Failed to load friend ledger');
        }
      },
    );
  }

  // ─── Expense Splitting & Settlements ─────────────────────────────────────────

  static Future<UserBalanceModel> calculateUserBalance({
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<UserBalanceModel>(
      key: 'splits:balance',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/splits/balances');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          return UserBalanceModel.fromJson(json.decode(response.body));
        } else {
          throw Exception('Failed to calculate user balance');
        }
      },
    );
  }

  static Future<List<SplitItemModel>> getExpenseSplits({
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<SplitItemModel>>(
      key: 'splits:all',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/splits/');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map(
                (item) => SplitItemModel.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        } else {
          throw Exception('Failed to load splits');
        }
      },
    );
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
      if (description != null && description.isNotEmpty)
        'description': description,
      'participants': participants,
    };

    final response = await _client
        .post(uri, headers: headers, body: json.encode(body))
        .timeout(_defaultTimeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      notifyDataChanged();
      invalidateCache('splits');
      return SplitItemModel.fromJson(json.decode(response.body));
    } else {
      String errorMsg = response.body;
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded.containsKey('detail')) {
          errorMsg = decoded['detail'].toString();
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  static Future<List<SettlementItemModel>> getSettlementHistory({
    String? friendName,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{};
    if (friendName != null && friendName.isNotEmpty) {
      queryParams['friend_name'] = friendName;
    }
    final key = 'splits:settlements:$queryParams';
    return _fetchWithCache<List<SettlementItemModel>>(
      key: key,
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/splits/settlements')
            .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map(
                (item) =>
                    SettlementItemModel.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        } else {
          throw Exception('Failed to load settlement history');
        }
      },
    );
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

    final response = await _client
        .post(uri, headers: headers, body: json.encode(body))
        .timeout(_defaultTimeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      notifyDataChanged();
      invalidateCache('splits');
      return SettlementItemModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to record settlement: ${response.body}');
    }
  }

  // ─── Financial Intelligence ──────────────────────────────────────────────────

  static Future<List<String>> detectUnusualSpending({
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<String>>(
      key: 'intelligence:unusual_spending',
      ttl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/intelligence/unusual-spending');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((item) => item.toString()).toList();
        } else {
          throw Exception('Failed to detect unusual spending');
        }
      },
    );
  }

  static Future<List<DetectedRecurringModel>> detectRecurringExpenses({
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<DetectedRecurringModel>>(
      key: 'intelligence:recurring',
      ttl: const Duration(minutes: 1),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/intelligence/recurring');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map(
                (item) => DetectedRecurringModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList();
        } else {
          throw Exception('Failed to detect recurring expenses');
        }
      },
    );
  }

  static Future<List<SubscriptionResponseModel>> detectSubscriptions({
    bool forceRefresh = false,
  }) async {
    return _fetchWithCache<List<SubscriptionResponseModel>>(
      key: 'intelligence:subscriptions',
      ttl: const Duration(minutes: 1),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final uri = Uri.parse('$baseUrl/intelligence/subscriptions');
        final headers = await _authHeaders();
        final response = await _getWithRetry(uri, headers);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data
              .map(
                (item) => SubscriptionResponseModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList();
        } else {
          throw Exception('Failed to detect subscriptions');
        }
      },
    );
  }

  // ─── AI Queries ──────────────────────────────────────────────────────────────

  static Future<NLQueryResponseModel> naturalLanguageQuery(
    String question,
  ) async {
    final uri = Uri.parse('$baseUrl/ai/query');
    final headers = await _authHeaders(jsonContent: true);
    final response = await _client
        .post(uri, headers: headers, body: json.encode({'question': question}))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return NLQueryResponseModel.fromJson(data);
    } else {
      throw Exception('Failed to process AI query: ${response.body}');
    }
  }
}
