import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/relay_service.dart';
import '../../shared/brand_mark.dart';
import '../../shared/field_label.dart';
import 'auth_controller.dart';

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
                  const SizedBox(height: 56),
                  Text(
                    _register ? '创建账号' : '连接你的 DSH',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _register
                        ? '注册后，用手机扫码绑定你的电脑。'
                        : '登录后访问已绑定电脑上的 DeepSeek Harness。',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: DshColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('登录')),
                      ButtonSegment(value: true, label: Text('注册')),
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
                        const FieldLabel('邮箱'),
                        TextFormField(
                          key: const Key('email-field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            hintText: 'name@example.com',
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email)) {
                              return '请输入有效邮箱。';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        const FieldLabel('密码'),
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
                            hintText: '至少 8 位',
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
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
                          validator: (value) =>
                              (value?.length ?? 0) < 8 ? '密码至少需要 8 位。' : null,
                        ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            state.errorMessage!,
                            key: const Key('auth-error'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: DshColors.danger),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('auth-submit'),
                          onPressed: state.busy ? null : _submit,
                          child: state.busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_register ? '创建账号' : '登录'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 15,
                        color: DshColors.mutedText,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          config.useMock
                              ? '当前使用 Mock Relay，可输入任意有效邮箱和 8 位密码。'
                              : '登录凭证仅保存在系统安全存储中。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
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
