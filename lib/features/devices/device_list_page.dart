import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(compact: true),
        actions: [
          IconButton(
            tooltip: '添加电脑',
            onPressed: _openPairing,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: '设置',
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
            Container(height: 1, color: DshColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我的电脑',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '选择一台电脑打开远程 DeepSeek Harness。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DshColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: devices.when(
                loading: () => const _DeviceSkeleton(),
                error: (error, _) => _DeviceError(
                  message: userMessage(error),
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
    final controller = TextEditingController(text: device.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名电脑'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: '电脑名称'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == device.name) return;
    try {
      await ref.read(deviceControllerProvider.notifier).rename(device.id, name);
    } catch (error) {
      if (mounted) _showError(userMessage(error));
    }
  }

  Future<void> _unbind(Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解绑电脑'),
        content: Text('解绑 ${device.name} 后，需要回到电脑前重新扫码。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DshColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解绑'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(deviceControllerProvider.notifier).unbind(device.id);
    } catch (error) {
      if (mounted) _showError(userMessage(error));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onOpen,
    required this.onRename,
    required this.onUnbind,
  });

  final Device device;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onUnbind;

  @override
  Widget build(BuildContext context) {
    final (color, status) = switch (device.availability) {
      DeviceAvailability.online => (DshColors.success, '在线'),
      DeviceAvailability.dshOffline => (DshColors.warning, 'DSH 未启动'),
      DeviceAvailability.offline => (DshColors.mutedText, '电脑离线'),
    };
    return Material(
      color: DshColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: DshColors.border),
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
                  color: DshColors.softSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.computer_outlined,
                  color: DshColors.navy,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
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
                          status,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (device.lastSeenAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _lastSeen(device.lastSeenAt!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '电脑操作',
                onSelected: (value) =>
                    value == 'rename' ? onRename() : onUnbind(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('重命名')),
                  PopupMenuItem(value: 'unbind', child: Text('解绑')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _lastSeen(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
    if (difference.inDays < 1) return '${difference.inHours} 小时前';
    return '${time.month} 月 ${time.day} 日';
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
          color: DshColors.softSurface,
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
            const Icon(
              Icons.cloud_off_outlined,
              size: 38,
              color: DshColors.secondaryText,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 70),
        const Icon(
          Icons.add_to_queue_outlined,
          size: 44,
          color: DshColors.secondaryText,
        ),
        const SizedBox(height: 16),
        Text(
          '还没有绑定电脑',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '在电脑上运行 dsh-remote，然后扫描终端中的配对码。',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: DshColors.secondaryText),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onPair,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('扫码配对'),
        ),
      ],
    );
  }
}
