import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_expense_tracker/features/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _MockHttpClientRequest();

  @override
  void close({bool force = false}) {}
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = 0;

  @override
  bool bufferOutput = true;

  @override
  bool persistentConnection = true;

  @override
  void add(List<int> data) {}

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  List<String>? operator [](String name) => null;
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _svg.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => true;

  @override
  String get reasonPhrase => 'OK';

  static final List<int> _svg = utf8.encode(
    '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" fill="black"/></svg>',
  );

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_svg]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  setUp(() {
    HttpOverrides.global = _MockHttpOverrides();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'ProfileScreen renders Delete Account button and triggers confirmation dialog',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pump();

      // Verify Delete Account is rendered on the screen
      final deleteButtons = find.text('Delete Account');
      expect(deleteButtons, findsWidgets);

      // Tap Delete Account button
      await tester.tap(deleteButtons.first);
      await tester.pump();

      // Verify confirmation dialog appears with warning text
      expect(
        find.textContaining('This will permanently delete all your data'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // Verify dialog dismissed
      expect(
        find.textContaining('This will permanently delete all your data'),
        findsNothing,
      );
    },
  );
}
