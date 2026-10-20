import '../../l10n/app_localizations.dart';
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
      ).showSnackBar(SnackBar(content: Text(context.l10n.text('upToDate'))));
      return;
    }
    await showAppUpdateDialog(context, result);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.text('updateCheckFailed'))),
    );
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
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return PopScope(
        canPop: !required,
        child: AlertDialog(
          scrollable: true,
          title: Text(
            required
                ? l10n.text('updateRequired')
                : l10n.text('updateAvailable'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.text('versionComparison', {
                  'installed': update.installed.version,
                  'latest': update.policy.latestVersion,
                }),
              ),
              if (update.policy.releaseNotes?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 14),
                Text(update.policy.releaseNotes!.trim()),
              ],
              if (required) ...[
                const SizedBox(height: 14),
                Text(l10n.text('unsupportedVersion')),
              ],
            ],
          ),
          actions: [
            if (!required)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.text('later')),
              ),
            FilledButton.icon(
              onPressed: () async {
                final opened = await launchUrl(
                  update.policy.downloadUrl!,
                  mode: LaunchMode.externalApplication,
                );
                if (!dialogContext.mounted) return;
                if (!opened) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(l10n.text('downloadFailed'))),
                  );
                } else if (!required) {
                  Navigator.of(dialogContext).pop();
                }
              },
              icon: const Icon(Icons.system_update_alt_rounded),
              label: Text(l10n.text('updateNow')),
            ),
          ],
        ),
      );
    },
  );
}
