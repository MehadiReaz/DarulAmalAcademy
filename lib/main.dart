import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Single ApiClient + TokenStorage for the whole app.
  final client = ApiClient();
  final storage = TokenStorage();

  runApp(DarulAmalApp(client: client, storage: storage));
}
