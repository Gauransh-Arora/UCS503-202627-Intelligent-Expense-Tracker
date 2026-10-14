import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../models/analytics_model.dart';

class ApiService {
  // Using 8000 as the port since Uvicorn runs on 8000.
  // The backend must be run with --host 0.0.0.0 for external access.
  static const String baseUrl = 'http://10.236.129.140:8000';
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

  // ─── Document Uploads ────────────────────────────────────────────────────────

  /// Uploads a document to the backend and returns the document ID.
  static Future<String> uploadDocument(String filePath) async {
    final uri = Uri.parse('$baseUrl/documents/upload');
    final request = http.MultipartRequest('POST', uri);
    
    // Attach the file
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    
    // Add default document type
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

  /// Processes the uploaded document to extract text and data using OCR.
  static Future<Map<String, dynamic>> processDocument(String documentId) async {
    final uri = Uri.parse('$baseUrl/documents/$documentId/process');
    debugPrint('Processing document at $uri...');
    
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
      debugPrint('Processing failed: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to process document');
    }
  }

  // ─── Data Fetching ────────────────────────────────────────────────────────────

  static Future<List<ExpenseModel>> getTransactions({int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/transactions/?limit=$limit');
    final token = await getToken();
    
    final response = await http.get(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ExpenseModel.fromJsonBackend(json)).toList();
    } else {
      throw Exception('Failed to load transactions: ${response.body}');
    }
  }

  static Future<AnalyticsSummary> getAnalyticsSummary() async {
    final uri = Uri.parse('$baseUrl/analytics/summary');
    final token = await getToken();
    
    final response = await http.get(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

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
}

