import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/relay_service.dart';
import '../../domain/models.dart';
import '../../shared/language_selector.dart';
import '../../shared/theme_selector.dart';
import '../auth/auth_controller.dart';
import '../devices/device_controller.dart';
import '../session/session_webview_page.dart';
import '../update/app_update_prompt.dart';
import '../update/app_update_service.dart';
import 'relay_settings_dialog.dart';
import 'remote_files_path.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final installedVersion = ref.watch(installedAppVersionProvider);
    final config = ref.watch(appConfigProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SettingsSection(
            title: l10n.text('account'),
            children: [_AccountEmailTile(email: auth.email ?? '')],
          ),
          const SizedBox(height: 16),
          // The card is the only surface: the controls must not draw their own
          // border, otherwise the section title labels a nested frame.
          _SettingsSection(
            title: l10n.text('language'),
            children: [
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: const LanguageSelector(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: l10n.text('theme'),
            children: [
              ListTile(
                leading: const Icon(Icons.contrast_rounded),
                title: const ThemeSelector(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: l10n.text('connection'),
            children: [
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(l10n.text('relayServer')),
                subtitle: Text(config.relayBaseUrl),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showRelaySettingsDialog(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.folder_copy_outlined),
                title: Text(l10n.text('remoteFiles')),
                subtitle: Text(l10n.text('remoteFilesHelp')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _selectDevice(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: l10n.text('about'),
            children: [
              ListTile(
                leading: const Icon(Icons.system_update_outlined),
                title: Text(l10n.text('version')),
                subtitle: Text(l10n.text('checkUpdates')),
                trailing: Text(
                  installedVersion.when(
                    data: (value) => value.displayVersion,
                    loading: () => '…',
                    error: (_, _) => l10n.text('unknown'),
                  ),
                ),
                onTap: () => checkForAppUpdate(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: Text(l10n.text('feedback')),
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
            icon: Icon(Icons.logout_rounded, color: context.dsh.danger),
            label: Text(
              l10n.text('logout'),
              style: TextStyle(color: context.dsh.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDevice(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final devices = ref.read(deviceControllerProvider);
    final items = devices.valueOrNull ?? const <Device>[];
    if (items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.text('noPairedComputers'))));
      return;
    }
    final selected = await showModalBottomSheet<Device>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(l10n.text('selectComputer'))),
            ...items.map(
              (device) => ListTile(
                leading: const Icon(Icons.computer_outlined),
                title: Text(l10n.deviceName(device)),
                subtitle: Text(
                  device.availability == DeviceAvailability.online
                      ? l10n.text('online')
                      : l10n.text('unavailable'),
                ),
                enabled: device.availability == DeviceAvailability.online,
                onTap: () => Navigator.pop(context, device),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    // The file browser has no language or theme switch of its own; it follows
    // the effective values of this app.
    final initialPath = remoteFilesPath(
      languageCode: Localizations.localeOf(context).languageCode,
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            SessionWebViewPage(device: selected, initialPath: initialPath),
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
    final palette = context.dsh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: palette.secondaryText),
          ),
        ),
        Material(
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// The account address is private by default: it is only revealed for the
/// current visit and is hidden again whenever Settings is reopened.
class _AccountEmailTile extends StatefulWidget {
  const _AccountEmailTile({required this.email});

  final String email;

  @override
  State<_AccountEmailTile> createState() => _AccountEmailTileState();
}

class _AccountEmailTileState extends State<_AccountEmailTile> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasEmail = widget.email.isNotEmpty;
    return ListTile(
      leading: const Icon(Icons.alternate_email_rounded),
      title: Text(l10n.text('loginEmail')),
      subtitle: Text(
        hasEmail ? (_revealed ? widget.email : l10n.text('emailHidden')) : '',
      ),
      trailing: hasEmail
          ? IconButton(
              tooltip: _revealed
                  ? l10n.text('hideEmail')
                  : l10n.text('showEmail'),
              icon: Icon(
                _revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _revealed = !_revealed),
            )
          : null,
    );
  }
}
