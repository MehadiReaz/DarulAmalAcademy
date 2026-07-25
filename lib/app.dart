import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/class_repository.dart';
import 'data/repositories/ticket_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/class_provider.dart';
import 'providers/ticket_provider.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/main_shell.dart';
import 'ui/screens/splash_screen.dart';

class DarulAmalApp extends StatelessWidget {
  final ApiClient client;
  final TokenStorage storage;

  const DarulAmalApp({
    super.key,
    required this.client,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repositories are plain objects — provided so widgets/providers
        // never construct their own ApiClient.
        Provider<ApiClient>.value(value: client),

        ChangeNotifierProvider(
          create: (_) =>
              AuthProvider(AuthRepository(client), storage, client)..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => ClassProvider(ClassRepository(client)),
        ),
        ChangeNotifierProvider(
          create: (_) => TicketProvider(TicketRepository(client)),
        ),
      ],
      child: MaterialApp(
        title: 'Darul Amal Academy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _RootGate(),
      ),
    );
  }
}

/// Swaps between splash / login / app shell based on auth status.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthProvider, AuthStatus>((p) => p.status);

    switch (status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        return const MainShell();
    }
  }
}
