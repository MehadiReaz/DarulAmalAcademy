import 'package:darul_amal/core/network/api_client.dart';
import 'package:darul_amal/core/network/api_exception.dart';
import 'package:darul_amal/core/storage/token_storage.dart';
import 'package:darul_amal/data/repositories/auth_repository.dart';
import 'package:darul_amal/data/repositories/quran_repository.dart';
import 'package:darul_amal/providers/auth_provider.dart';
import 'package:darul_amal/providers/quran_provider.dart';
import 'package:darul_amal/ui/screens/quran/quran_tab.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeClient extends ApiClient {
  final Object Function() respond;
  _FakeClient(this.respond);

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final r = respond();
    if (r is ApiException) throw r;
    return r;
  }
}

Future<void> _pump(WidgetTester tester, _FakeClient client) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              AuthProvider(AuthRepository(client), TokenStorage(), client),
        ),
        ChangeNotifierProvider(
          create: (_) => QuranProvider(QuranRepository(client)),
        ),
      ],
      child: const MaterialApp(home: QuranTab()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no progress and no logs shows only "No information found"',
      (tester) async {
    await _pump(tester, _FakeClient(() => <String, dynamic>{}));

    expect(find.text('No information found'), findsOneWidget);
    expect(find.textContaining('Student:'), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a failed load shows the error with retry, not "no data"',
      (tester) async {
    await _pump(
      tester,
      _FakeClient(() => const ApiException(message: 'Server unreachable')),
    );

    expect(find.text('Server unreachable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('No information found'), findsNothing);
  });
}
