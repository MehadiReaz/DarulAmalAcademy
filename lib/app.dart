import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/storage/read_state_storage.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/attendance_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/class_repository.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/repositories/fee_repository.dart';
import 'data/repositories/homework_repository.dart';
import 'data/repositories/notice_repository.dart';
import 'data/repositories/quran_repository.dart';
import 'data/repositories/recording_repository.dart';
import 'data/repositories/ticket_repository.dart';
import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/class_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/fee_provider.dart';
import 'providers/homework_provider.dart';
import 'providers/notice_provider.dart';
import 'providers/quran_provider.dart';
import 'providers/recording_provider.dart';
import 'providers/shell_provider.dart';
import 'providers/ticket_provider.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/main_shell.dart';
import 'ui/screens/splash_screen.dart';

class DarulAmalApp extends StatelessWidget {
  final ApiClient client;
  final TokenStorage storage;
  final ReadStateStorage readState;

  const DarulAmalApp({
    super.key,
    required this.client,
    required this.storage,
    required this.readState,
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
          create: (_) => DashboardProvider(DashboardRepository(client)),
        ),
        ChangeNotifierProvider(
          create: (_) => NoticeProvider(NoticeRepository(client), readState),
        ),
        ChangeNotifierProvider(
          create: (_) => TicketProvider(TicketRepository(client)),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeworkProvider(HomeworkRepository(client)),
        ),
        ChangeNotifierProvider(
          create: (_) => FeeProvider(FeeRepository(client)),
        ),
        ChangeNotifierProvider(
          create: (_) => AttendanceProvider(AttendanceRepository(client)),
        ),
        ChangeNotifierProvider(
          create: (_) => RecordingProvider(RecordingRepository(client)),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(ChatRepository(client)),
        ),
        ChangeNotifierProvider(
          create: (_) => QuranProvider(QuranRepository(client)),
        ),
        // Owns the selected bottom-nav tab so nested screens can navigate.
        ChangeNotifierProvider(create: (_) => ShellProvider()),
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
