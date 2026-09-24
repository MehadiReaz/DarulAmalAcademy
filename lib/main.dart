import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/utils/responsive.dart';
import 'core/network/api_client.dart';
import 'core/services/fcm_service.dart';
import 'core/storage/read_state_storage.dart';
import 'core/storage/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phones stay portrait; tablets rotate freely.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final screen = view.physicalSize / view.devicePixelRatio;
  if (!Responsive.isTabletDevice(screen)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

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
