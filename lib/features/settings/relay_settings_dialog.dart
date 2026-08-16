import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../data/relay_config_store.dart';
import '../../data/relay_service.dart';
import '../auth/auth_controller.dart';

Future<void> showRelaySettingsDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final current = ref.read(appConfigProvider);
  final selected = await showDialog<String>(
    context: context,
    builder: (context) =>
        _RelaySettingsDialog(initialUrl: current.relayBaseUrl),
  );
  if (selected == null) return;
  final next = current.withRelayBaseUrl(selected);
  next.validate(isRelease: const bool.fromEnvironment('dart.vm.product'));
  await ref
      .read(relayConfigStoreProvider)
      .writeRelayUrl(
        next.relayBaseUrl == AppConfig.productionRelayUrl
            ? null
            : next.relayBaseUrl,
      );
  await ref.read(authControllerProvider.notifier).logout();
  ref.read(appConfigProvider.notifier).state = next;
}

class _RelaySettingsDialog extends StatefulWidget {
  const _RelaySettingsDialog({required this.initialUrl});

  final String initialUrl;

  @override
  State<_RelaySettingsDialog> createState() => _RelaySettingsDialogState();
}

class _RelaySettingsDialogState extends State<_RelaySettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Relay 服务器'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('relay-url-field'),
          controller: _controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'HTTPS 地址',
            hintText: 'https://relay.example.com',
          ),
          validator: (value) {
            final uri = Uri.tryParse(value?.trim() ?? '');
            if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
              return '请输入有效的 HTTPS Relay 地址。';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, AppConfig.productionRelayUrl),
          child: const Text('使用公共 Relay'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
