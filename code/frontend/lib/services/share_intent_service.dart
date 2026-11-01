import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/constants/app_constants.dart';
import '../core/routing/app_router.dart';

enum SharedType { file, text }

class PendingShare {
  final SharedType type;
  final String payload;
  final Map<String, dynamic>? extra;
  final DateTime timestamp;

  PendingShare({
    required this.type,
    required this.payload,
    this.extra,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ShareIntentService {
  static StreamSubscription? _intentDataStreamSubscription;
  static bool isReady = false;
  static PendingShare? _pendingShare;
  static Completer<void> _initialCompleter = Completer<void>();
  static String? _lastHandledPayload;
  static DateTime? _lastHandledTime;

  static bool get hasPendingShare => _pendingShare != null;
  static PendingShare? get pendingShare => _pendingShare;

  /// Atomically consumes and returns the pending share (if any).
  static PendingShare? consumePendingShare() {
    final share = _pendingShare;
    _pendingShare = null;
    return share;
  }

  /// Helper for testing to set or clear pending share.
  @visibleForTesting
  static void setPendingShareForTesting(PendingShare? share) {
    _pendingShare = share;
  }

  /// Awaits the resolution of getInitialMedia with a safe timeout.
  static Future<void> waitForInitialShare({
    Duration timeout = const Duration(milliseconds: 1000),
  }) async {
    try {
      await _initialCompleter.future.timeout(timeout, onTimeout: () {});
    } catch (_) {}
  }

  static void init() {
    isReady = false;
    _initialCompleter = Completer<void>();

    // ── Listen while app is running (handles warm starts & late events) ────────
    _intentDataStreamSubscription?.cancel();
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isEmpty) return;
            final validFile = _findFirstValid(value);
            if (validFile == null) return;

            final path = validFile.path.trim();
            if (_isDuplicate(path)) return;
            _markHandled(path);

            if (isReady && AppRouter.rootNavigatorKey.currentContext != null) {
              // Warm-start: app is already rendered and ready
              if (validFile.type == SharedMediaType.text) {
                _dispatchText(path);
              } else {
                _dispatchFile(path);
              }
            } else {
              // Cold-start / app not ready: store as pending
              _storePending(validFile, path);
            }
          },
          onError: (err) {
            debugPrint("ShareIntentService getMediaStream error: $err");
          },
        );

    // ── Handle cold-start share ───────────────────────────────────────────────
    ReceiveSharingIntent.instance.getInitialMedia().then(
      (List<SharedMediaFile> value) {
        try {
          if (value.isNotEmpty) {
            final validFile = _findFirstValid(value);
            if (validFile != null) {
              final path = validFile.path.trim();
              if (!_isDuplicate(path)) {
                _markHandled(path);
                _storePending(validFile, path);
              }
            }
          }
        } finally {
          // Reset the native intent only AFTER saving into Dart memory (_pendingShare)
          ReceiveSharingIntent.instance.reset();
          if (!_initialCompleter.isCompleted) {
            _initialCompleter.complete();
          }
        }
      },
      onError: (err) {
        debugPrint("ShareIntentService getInitialMedia error: $err");
        if (!_initialCompleter.isCompleted) {
          _initialCompleter.complete();
        }
      },
    );
  }

  static SharedMediaFile? _findFirstValid(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.path.trim().isNotEmpty) {
        return f;
      }
    }
    return null;
  }

  static void _storePending(SharedMediaFile file, String path) {
    if (file.type == SharedMediaType.text) {
      _pendingShare = PendingShare(
        type: SharedType.text,
        payload: path,
        extra: _parseUpiText(path),
      );
    } else {
      _pendingShare = PendingShare(type: SharedType.file, payload: path);
    }
  }

  static bool _isDuplicate(String payload) {
    final now = DateTime.now();
    if (_pendingShare != null && _pendingShare!.payload == payload) {
      return true;
    }
    if (_lastHandledPayload == payload &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(seconds: 3)) {
      return true;
    }
    return false;
  }

  static void _markHandled(String payload) {
    _lastHandledPayload = payload;
    _lastHandledTime = DateTime.now();
  }

  /// Called after successful login/registration or when app becomes ready.
  /// If a pending share exists, navigates directly to the preview screen.
  /// Otherwise, navigates to the Home dashboard.
  static void navigatePendingShareOrHome(BuildContext context) {
    isReady = true;
    final share = consumePendingShare();
    if (share != null) {
      if (share.type == SharedType.file) {
        AppRouter.router.go(
          '/image-preview',
          extra: {'source': 'shared', 'filePath': share.payload},
        );
      } else {
        final extra = Map<String, dynamic>.from(share.extra ?? {});
        extra['rawText'] = share.payload;
        AppRouter.router.go('/shared-text-expense', extra: extra);
      }
    } else {
      AppRouter.router.go(AppConstants.routeHome);
    }
  }

  /// Backward-compatible method for components calling onAppReady.
  static void onAppReady() {
    isReady = true;
    if (_pendingShare != null) {
      final share = consumePendingShare()!;
      if (share.type == SharedType.file) {
        _dispatchFile(share.payload);
      } else {
        _dispatchText(share.payload);
      }
    }
  }

  // ── Dispatchers for Warm Start ──────────────────────────────────────────────
  static void _dispatchFile(String filePath) {
    AppRouter.router.push(
      '/image-preview',
      extra: {'source': 'shared', 'filePath': filePath},
    );
  }

  static void _dispatchText(String text) {
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
  static Map<String, String?> _parseUpiText(String text) {
    String? amount;
    String? merchant;
    String? note;

    final amountRegex = RegExp(
      r'(?:Rs\.?\s*|₹\s*|INR\s*)([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final amountMatch = amountRegex.firstMatch(text);
    if (amountMatch != null) {
      amount = amountMatch.group(1)?.replaceAll(',', '');
    }

    final merchantRegex = RegExp(
      r"(?:paid?\s+to|payment\s+(?:of\s+(?:Rs\.?\s*[\d,]+(?:\.\d+)?\s+)?to)|to)\s+([A-Za-z0-9 &'\.\-]+?)(?:\s*\(|\s+(?:is|on|via|for|ref|txn|transaction)|$)",
      caseSensitive: false,
    );
    final merchantMatch = merchantRegex.firstMatch(text);
    if (merchantMatch != null) {
      merchant = merchantMatch.group(1)?.trim();
    }

    final txnRegex = RegExp(
      r'(?:transaction\s+id|txn\s+id|ref\s*(?:no)?\.?)\s*[:\-]?\s*([A-Z0-9]+)',
      caseSensitive: false,
    );
    final txnMatch = txnRegex.firstMatch(text);
    if (txnMatch != null) {
      note = 'UPI Txn: ${txnMatch.group(1)}';
    }

    return {'amount': amount, 'merchant': merchant, 'note': note};
  }

  static void dispose() {
    _intentDataStreamSubscription?.cancel();
    isReady = false;
    _pendingShare = null;
    if (!_initialCompleter.isCompleted) {
      _initialCompleter.complete();
    }
    _initialCompleter = Completer<void>();
  }
}
