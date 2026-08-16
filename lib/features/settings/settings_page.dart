import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../update/app_update_prompt.dart';
import '../update/app_update_service.dart';
import '../../data/relay_service.dart';
import 'relay_settings_dialog.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final installedVersion = ref.watch(installedAppVersionProvider);
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SettingsSection(
            title: '账号',
            children: [
              ListTile(
                leading: const Icon(Icons.alternate_email_rounded),
                title: const Text('登录邮箱'),
                subtitle: Text(auth.email ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '连接',
            children: [
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Relay 服务器'),
                subtitle: Text(config.relayBaseUrl),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showRelaySettingsDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '关于',
            children: [
              ListTile(
                leading: const Icon(Icons.system_update_outlined),
                title: const Text('版本'),
                subtitle: const Text('点击检查更新'),
                trailing: Text(
                  installedVersion.when(
                    data: (value) => value.displayVersion,
                    loading: () => '…',
                    error: (_, _) => '未知',
                  ),
                ),
                onTap: () => checkForAppUpdate(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('意见反馈'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => launchUrl(
                  Uri.parse(
                    'mailto:feedback@deepseek.com?subject=DSH%20Remote',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.logout_rounded, color: DshColors.danger),
            label: const Text(
              '退出登录',
              style: TextStyle(color: DshColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: DshColors.secondaryText),
          ),
        ),
        Material(
          color: DshColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: DshColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}
