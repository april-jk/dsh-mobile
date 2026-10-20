import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/device_key_store.dart';
import '../../data/relay_service.dart';
import '../../domain/models.dart';
import '../../shared/brand_mark.dart';
import '../pairing/pair_page.dart';
import '../session/session_webview_page.dart';
import '../settings/settings_page.dart';
import 'device_controller.dart';

class DeviceListPage extends ConsumerStatefulWidget {
  const DeviceListPage({super.key});

  @override
  ConsumerState<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends ConsumerState<DeviceListPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(ref.read(deviceControllerProvider.notifier).load);
  }

  Future<void> _openPairing() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const PairPage()));
    await ref.read(deviceControllerProvider.notifier).load(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(deviceControllerProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(compact: true),
        actions: [
          IconButton(
            tooltip: l10n.text('addComputer'),
            onPressed: _openPairing,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: l10n.text('settings'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 1, color: context.dsh.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.text('myComputers'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.text('devicesIntro'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.dsh.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: devices.when(
                loading: () => const _DeviceSkeleton(),
                error: (error, _) => _DeviceError(
                  message: l10n.error(error),
                  onRetry: ref.read(deviceControllerProvider.notifier).load,
                ),
                data: (items) => RefreshIndicator(
                  onRefresh: () => ref
                      .read(deviceControllerProvider.notifier)
                      .load(showLoading: false),
                  child: items.isEmpty
                      ? _EmptyDevices(onPair: _openPairing)
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _DeviceTile(
                            device: items[index],
                            onOpen: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SessionWebViewPage(device: items[index]),
                              ),
                            ),
                            onRename: () => _rename(items[index]),
                            onUnbind: () => _unbind(items[index]),
                            onBrowser: () => _openBrowser(items[index]),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(Device device) async {
    final l10n = context.l10n;
    final currentName = l10n.deviceName(device);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameComputerDialog(initialName: currentName),
    );
    if (name == null || name.isEmpty || name == currentName) return;
    try {
      await ref.read(deviceControllerProvider.notifier).rename(device.id, name);
    } catch (error) {
      if (mounted) _showError(l10n.error(error));
    }
  }

  Future<void> _unbind(Device device) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.text('removePairing')),
        content: Text(
          l10n.text('removePairingBody', {'name': l10n.deviceName(device)}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.text('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.dsh.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.text('removePairing')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(deviceControllerProvider.notifier).unbind(device.id);
    } catch (error) {
      if (mounted) _showError(l10n.error(error));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openBrowser(Device device) async {
    final l10n = context.l10n;
    final key = await ref.read(deviceKeyStoreProvider).read(device.id);
    if (!mounted) return;
    if (key == null) {
      _showError(l10n.text('missingKey'));
      return;
    }
    final relay = ref.read(appConfigProvider).relayBaseUrl;
    final uri = Uri.parse(relay).replace(
      path: '/app/',
      query: '',
      fragment:
          '/web-pair?device=${Uri.encodeComponent(device.id)}&key=${Uri.encodeComponent(key)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showError(l10n.text('browserFailed'));
    }
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onOpen,
    required this.onRename,
    required this.onUnbind,
    required this.onBrowser,
  });

  final Device device;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onUnbind;
  final VoidCallback onBrowser;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.dsh;
    final (color, statusKey) = switch (device.availability) {
      DeviceAvailability.online => (palette.success, 'online'),
      DeviceAvailability.dshOffline => (palette.warning, 'dshOffline'),
      DeviceAvailability.offline => (palette.mutedText, 'computerOffline'),
    };
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: palette.border),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.softSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.computer_outlined, color: palette.navy),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.deviceName(device),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          l10n.text(statusKey),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (device.lastSeenAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _lastSeen(context, device.lastSeenAt!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: l10n.text('computerActions'),
                onSelected: (value) {
                  switch (value) {
                    case 'browser':
                      onBrowser();
                    case 'rename':
                      onRename();
                    case 'unbind':
                      onUnbind();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'browser',
                    child: Text(l10n.text('useBrowser')),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(l10n.text('rename')),
                  ),
                  PopupMenuItem(
                    value: 'unbind',
                    child: Text(l10n.text('removePairing')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _lastSeen(BuildContext context, DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inDays >= 1) {
      return MaterialLocalizations.of(context).formatShortDate(time.toLocal());
    }
    return context.l10n.relativeTime(time);
  }
}

class _DeviceSkeleton extends StatelessWidget {
  const _DeviceSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Container(
        height: 74,
        decoration: BoxDecoration(
          color: context.dsh.softSurface,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _DeviceError extends StatelessWidget {
  const _DeviceError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 38,
              color: context.dsh.secondaryText,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.text('retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({required this.onPair});

  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 70),
        Icon(
          Icons.add_to_queue_outlined,
          size: 44,
          color: context.dsh.secondaryText,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.text('noComputers'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.text('noComputersIntro'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.dsh.secondaryText),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onPair,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: Text(l10n.text('scanPair')),
        ),
      ],
    );
  }
}

/// Owns the text controller for its whole route lifetime so the dialog
/// subtree never reads a controller that was disposed during the pop
/// animation.
class _RenameComputerDialog extends StatefulWidget {
  const _RenameComputerDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameComputerDialog> createState() => _RenameComputerDialogState();
}

class _RenameComputerDialogState extends State<_RenameComputerDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.text('renameComputer')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        decoration: InputDecoration(labelText: l10n.text('computerName')),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.text('cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.text('save'))),
      ],
    );
  }
}
