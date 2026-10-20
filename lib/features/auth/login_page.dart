import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/relay_service.dart';
import '../../shared/brand_mark.dart';
import '../../shared/field_label.dart';
import 'auth_controller.dart';
import '../settings/relay_settings_dialog.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _register = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .submit(
          email: _emailController.text,
          password: _passwordController.text,
          register: _register,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BrandMark(),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _register
                        ? l10n.text('createAccount')
                        : l10n.text('connectDsh'),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _register
                        ? l10n.text('registerIntro')
                        : l10n.text('loginIntro'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.dsh.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(l10n.text('login')),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(l10n.text('register')),
                      ),
                    ],
                    selected: {_register},
                    showSelectedIcon: false,
                    onSelectionChanged: state.busy
                        ? null
                        : (selection) => setState(() {
                            _register = selection.first;
                          }),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FieldLabel(l10n.text('email')),
                        TextFormField(
                          key: const Key('email-field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            hintText: 'name@example.com',
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email)) {
                              return l10n.text('validEmail');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        FieldLabel(l10n.text('password')),
                        TextFormField(
                          key: const Key('password-field'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: _register
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: l10n.text('passwordHint'),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? l10n.text('showPassword')
                                  : l10n.text('hidePassword'),
                              onPressed: () => setState(() {
                                _obscurePassword = !_obscurePassword;
                              }),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => (value?.length ?? 0) < 8
                              ? l10n.text('passwordLength')
                              : null,
                        ),
                        if (state.error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            l10n.error(state.error!),
                            key: const Key('auth-error'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.dsh.danger),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('auth-submit'),
                          onPressed: state.busy ? null : _submit,
                          child: state.busy
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                )
                              : Text(
                                  _register
                                      ? l10n.text('createAccount')
                                      : l10n.text('login'),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 15,
                        color: context.dsh.mutedText,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          config.useMock
                              ? l10n.text('mockLogin')
                              : l10n.text('secureCredentials'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => showRelaySettingsDialog(context, ref),
                    icon: const Icon(Icons.dns_outlined, size: 18),
                    label: Text(
                      l10n.text('relayHost', {'host': config.relayOrigin.host}),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
