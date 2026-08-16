import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/devices/device_list_page.dart';
import 'features/update/app_update_prompt.dart';

class DshRemoteApp extends StatelessWidget {
  const DshRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSH Remote',
      debugShowCheckedModeBanner: false,
      theme: buildDshTheme(),
      home: const AppUpdateCoordinator(child: AuthGate()),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return switch (auth.status) {
      AuthStatus.initializing => const _StartupScreen(),
      AuthStatus.unauthenticated => const LoginPage(),
      AuthStatus.authenticated => const DeviceListPage(),
    };
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
