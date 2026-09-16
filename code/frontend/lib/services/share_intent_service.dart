import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../core/routing/app_router.dart';

class ShareIntentService {
  static StreamSubscription? _intentDataStreamSubscription;

  static void init() {
    // ── Listen while app is running in memory ──────────────────────────────
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          final file = value.first;
          if (file.type == SharedMediaType.text) {
            _handleSharedText(file.path); // 'path' carries the text for type=text
          } else {
            _handleSharedFile(file.path);
          }
        }
      },
      onError: (err) {
        debugPrint("ShareIntentService getMediaStream error: $err");
      },
    );

    // ── Handle cold-start share ────────────────────────────────────────────
    ReceiveSharingIntent.instance.getInitialMedia().then(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          final file = value.first;
          if (file.type == SharedMediaType.text) {
            _handleSharedText(file.path);
          } else {
            _handleSharedFile(file.path);
          }
        }
        ReceiveSharingIntent.instance.reset();
      },
      onError: (err) {
        debugPrint("ShareIntentService getInitialMedia error: $err");
      },
    );
  }

  static bool isReady = false;
  static String? _pendingFile;
  static String? _pendingText;

  static void onAppReady() {
    isReady = true;
    if (_pendingFile != null) {
      _handleSharedFile(_pendingFile!);
      _pendingFile = null;
    }
    if (_pendingText != null) {
      _handleSharedText(_pendingText!);
      _pendingText = null;
    }
  }

  // ── Image / file handler ─────────────────────────────────────────────────
  static void _handleSharedFile(String filePath) {
    if (!isReady || AppRouter.rootNavigatorKey.currentContext == null) {
      _pendingFile = filePath;
      return;
    }
    AppRouter.router.push(
      '/image-preview',
      extra: {
        'source': 'shared',
        'filePath': filePath,
      },
    );
  }

  // ── Text / UPI payment handler ───────────────────────────────────────────
  static void _handleSharedText(String text) {
    if (!isReady || AppRouter.rootNavigatorKey.currentContext == null) {
      _pendingText = text;
      return;
    }
    final parsed = _parseUpiText(text);
    AppRouter.router.push(
      '/shared-text-expense',
      extra: {
        'rawText': text,
        'amount': parsed['amount'],
        'merchant': parsed['merchant'],
        'note': parsed['note'],
      },
    );
  }

  /// Parses common UPI/BHIM payment message formats and extracts key fields.
  ///
  /// Example BHIM UPI message:
  ///   "Payment of Rs. 250.00 to Swiggy (swiggy@upi) is successful.
  ///    Transaction ID: 123456789012"
  ///
  /// Example GPay message:
  ///   "You paid ₹500 to John Doe on 15 Sep"
  static Map<String, String?> _parseUpiText(String text) {
    String? amount;
    String? merchant;
    String? note;

    // ── Amount ──────────────────────────────────────────────────────────────
    // Matches: Rs. 250.00 | Rs 250 | ₹250 | INR 250
    final amountRegex = RegExp(
      r'(?:Rs\.?\s*|₹\s*|INR\s*)([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final amountMatch = amountRegex.firstMatch(text);
    if (amountMatch != null) {
      amount = amountMatch.group(1)?.replaceAll(',', '');
    }

    // ── Merchant ────────────────────────────────────────────────────────────
    // "to <merchant>" pattern — common across BHIM, GPay, PhonePe
    final merchantRegex = RegExp(
      r"(?:paid?\s+to|payment\s+(?:of\s+(?:Rs\.?\s*[\d,]+(?:\.\d+)?\s+)?to)|to)\s+([A-Za-z0-9 &'\.\-]+?)(?:\s*\(|\s+(?:is|on|via|for|ref|txn|transaction)|$)",
      caseSensitive: false,
    );
    final merchantMatch = merchantRegex.firstMatch(text);
    if (merchantMatch != null) {
      merchant = merchantMatch.group(1)?.trim();
    }

    // ── Transaction ID as note ───────────────────────────────────────────────
    final txnRegex = RegExp(
      r'(?:transaction\s+id|txn\s+id|ref\s*(?:no)?\.?)\s*[:\-]?\s*([A-Z0-9]+)',
      caseSensitive: false,
    );
    final txnMatch = txnRegex.firstMatch(text);
    if (txnMatch != null) {
      note = 'UPI Txn: ${txnMatch.group(1)}';
    }

    return {
      'amount': amount,
      'merchant': merchant,
      'note': note,
    };
  }

  static void dispose() {
    _intentDataStreamSubscription?.cancel();
  }
}
