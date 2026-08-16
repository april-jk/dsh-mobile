import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_service.dart';

class AppUpdateCoordinator extends ConsumerStatefulWidget {
  const AppUpdateCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppUpdateCoordinator> createState() =>
      _AppUpdateCoordinatorState();
}

class _AppUpdateCoordinatorState extends ConsumerState<AppUpdateCoordinator>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _showingPrompt = false;
  String? _lastOptionalPrompt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking || _showingPrompt || !mounted) return;
    _checking = true;
    try {
      ref.invalidate(appUpdateCheckProvider);
      final result = await ref.read(appUpdateCheckProvider.future);
      if (!mounted || result == null) return;
      if (result.requirement == AppUpdateRequirement.none) return;
      if (result.requirement == AppUpdateRequirement.optional &&
          _lastOptionalPrompt == result.policy.latestVersion) {
        return;
      }
      _showingPrompt = true;
      if (result.requirement == AppUpdateRequirement.optional) {
        _lastOptionalPrompt = result.policy.latestVersion;
      }
      await showAppUpdateDialog(context, result);
    } catch (_) {
      // Automatic checks stay silent when the Relay or app store is unavailable.
    } finally {
      _checking = false;
      _showingPrompt = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> checkForAppUpdate(BuildContext context, WidgetRef ref) async {
  try {
    ref.invalidate(appUpdateCheckProvider);
    final result = await ref.read(appUpdateCheckProvider.future);
    if (!context.mounted) return;
    if (result == null || result.requirement == AppUpdateRequirement.none) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前已是最新版本。')));
      return;
    }
    await showAppUpdateDialog(context, result);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('暂时无法检查更新，请稍后重试。')));
  }
}

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateCheck update,
) async {
  final required = update.requirement == AppUpdateRequirement.required;
  await showDialog<void>(
    context: context,
    barrierDismissible: !required,
    builder: (dialogContext) => PopScope(
      canPop: !required,
      child: AlertDialog(
        scrollable: true,
        title: Text(required ? '需要更新' : '发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前 ${update.installed.version}  ·  最新 ${update.policy.latestVersion}',
            ),
            if (update.policy.releaseNotes?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Text(update.policy.releaseNotes!.trim()),
            ],
            if (required) ...[
              const SizedBox(height: 14),
              const Text('当前版本已不再支持，更新后才能继续使用。'),
            ],
          ],
        ),
        actions: [
          if (!required)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('稍后'),
            ),
          FilledButton.icon(
            onPressed: () async {
              final opened = await launchUrl(
                update.policy.downloadUrl!,
                mode: LaunchMode.externalApplication,
              );
              if (!dialogContext.mounted) return;
              if (!opened) {
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(const SnackBar(content: Text('无法打开下载页面。')));
              } else if (!required) {
                Navigator.of(dialogContext).pop();
              }
            },
            icon: const Icon(Icons.system_update_alt_rounded),
            label: const Text('立即更新'),
          ),
        ],
      ),
    ),
  );
}
