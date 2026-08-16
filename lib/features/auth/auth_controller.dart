import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../data/relay_service.dart';
import '../../data/token_store.dart';

enum AuthStatus { initializing, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.email,
    this.busy = false,
    this.errorMessage,
  });

  const AuthState.initializing() : this(status: AuthStatus.initializing);

  final AuthStatus status;
  final String? email;
  final bool busy;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final controller = AuthController(
      service: ref.watch(relayServiceProvider),
      tokenStore: ref.watch(tokenStoreProvider),
    );
    Future<void>.microtask(controller.bootstrap);
    return controller;
  },
);

class AuthController extends StateNotifier<AuthState> {
  AuthController({required this.service, required this.tokenStore})
    : super(const AuthState.initializing()) {
    _sessionExpiredSubscription = service.sessionExpired.listen((_) {
      unawaited(_expireSession());
    });
  }

  final RelayService service;
  final TokenStore tokenStore;
  late final StreamSubscription<void> _sessionExpiredSubscription;

  @override
  void dispose() {
    _sessionExpiredSubscription.cancel();
    super.dispose();
  }

  Future<void> _expireSession() async {
    await tokenStore.clear();
    if (!mounted) return;
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: '登录已过期，请重新登录。',
    );
  }

  Future<void> bootstrap() async {
    final refreshToken = await tokenStore.readRefreshToken();
    final email = await tokenStore.readEmail();
    if (refreshToken == null || email == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final tokens = await service.refresh(refreshToken);
      await tokenStore.write(tokens, email: email);
      state = AuthState(status: AuthStatus.authenticated, email: email);
    } catch (_) {
      await tokenStore.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> submit({
    required String email,
    required String password,
    required bool register,
  }) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final tokens = register
          ? await service.register(normalizedEmail, password)
          : await service.login(normalizedEmail, password);
      await tokenStore.write(tokens, email: normalizedEmail);
      state = AuthState(
        status: AuthStatus.authenticated,
        email: normalizedEmail,
      );
      return true;
    } catch (error) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        busy: false,
        errorMessage: userMessage(error),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await tokenStore.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
