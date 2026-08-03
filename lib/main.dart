import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/services/fcm_service.dart';
import 'core/storage/read_state_storage.dart';
import 'core/storage/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase & Push Notification Service
  await FcmService.initialize();

  // Single ApiClient + storage instances for the whole app.
  final client = ApiClient();
  final storage = TokenStorage();
  final readState = ReadStateStorage();

  runApp(DarulAmalApp(
    client: client,
    storage: storage,
    readState: readState,
  ));
}
