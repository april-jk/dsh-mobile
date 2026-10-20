import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/analytics.dart';
import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../data/device_key_store.dart';
import '../../data/relay_service.dart';
import '../devices/device_controller.dart';
import 'pair_payload_parser.dart';

class PairPage extends ConsumerStatefulWidget {
  const PairPage({super.key});

  @override
  ConsumerState<PairPage> createState() => _PairPageState();
}

class _PairPageState extends ConsumerState<PairPage> {
  final _codeController = TextEditingController();
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _manual = false;
  bool _submitting = false;
  bool _waitingForConfirmation = false;
  String? _claimedDeviceId;
  _ErrorDetail? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleRawValue(String raw) async {
    if (_submitting || _claimedDeviceId != null) return;
    try {
      final payload = parsePairPayload(raw);
      final config = ref.read(appConfigProvider);
      if (!relayMatches(payload.relay, config.relayOrigin)) {
        throw const ApiException('relay_mismatch');
      }
      setState(() {
        _submitting = true;
        _error = null;
      });
      await _scannerController.stop();
      final deviceId = await ref
          .read(relayServiceProvider)
          .claimPair(payload.code);
      await ref.read(deviceKeyStoreProvider).write(deviceId, payload.e2eeKey);
      if (!mounted) return;
      setState(() {
        _claimedDeviceId = deviceId;
        _submitting = false;
        _waitingForConfirmation = true;
      });
      await _waitForConfirmation();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _ErrorDetail(error);
      });
      if (!_manual) await _scannerController.start();
    }
  }

  Future<void> _waitForConfirmation() async {
    final deviceId = _claimedDeviceId;
    if (deviceId == null || !_waitingForConfirmation) return;
    try {
      final device = await ref
          .read(deviceControllerProvider.notifier)
          .waitForDevice(deviceId);
      if (!mounted) return;
      if (device == null) {
        setState(() {
          _waitingForConfirmation = false;
          _error = const _ErrorDetail(null, key: 'confirmationPending');
        });
        return;
      }
      ref.read(analyticsProvider).track('pair_success', {'deviceId': deviceId});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.text('pairSuccess', {
              'name': context.l10n.deviceName(device),
            }),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _waitingForConfirmation = false;
        _error = _ErrorDetail(error, key: 'claimedError');
      });
    }
  }

  void _continueWaiting() {
    setState(() {
      _waitingForConfirmation = true;
      _error = null;
    });
    _waitForConfirmation();
  }

  Future<void> _submitManualCode() async {
    setState(() => _error = const _ErrorDetail(null, key: 'manualUnsupported'));
  }

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (value != null) _handleRawValue(value);
  }

  Future<void> _setMode(bool manual) async {
    if (_submitting || manual == _manual) return;
    setState(() {
      _manual = manual;
      _error = null;
    });
    if (manual) {
      await _scannerController.stop();
    } else {
      await _scannerController.start();
    }
  }

  String _errorText() {
    final detail = _error;
    if (detail == null) return '';
    final l10n = context.l10n;
    final key = detail.key;
    if (key == null) return l10n.error(detail.error!);
    return l10n.text(
      key,
      detail.error == null ? const {} : {'error': l10n.error(detail.error!)},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('pairComputer'))),
      body: SafeArea(
        top: false,
        child: _claimedDeviceId != null
            ? _confirmationState(context)
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(l10n.text('scan')),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.dialpad_rounded),
                        label: Text(l10n.text('manualEntry')),
                      ),
                    ],
                    selected: {_manual},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        _setMode(selection.first),
                  ),
                  const SizedBox(height: 24),
                  if (_manual) _manualInput(context) else _scanner(context),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorText(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.dsh.danger,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _confirmationState(BuildContext context) {
    final l10n = context.l10n;
    final String status;
    if (_waitingForConfirmation) {
      status = l10n.text('claimedWaiting');
    } else if (_error != null) {
      status = _errorText();
    } else {
      status = l10n.text('notConfirmed');
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _waitingForConfirmation
                    ? Icons.sync_rounded
                    : Icons.schedule_rounded,
                size: 44,
                color: context.dsh.navy,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.text('waitingComputer'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.dsh.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              if (_waitingForConfirmation)
                const CircularProgressIndicator(strokeWidth: 2)
              else ...[
                FilledButton.icon(
                  onPressed: _continueWaiting,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.text('continueWaiting')),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.text('backDevices')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _scanner(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                CustomPaint(painter: const _ScannerFramePainter()),
                if (_submitting)
                  const ColoredBox(
                    color: Color(0x88000000),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.l10n.text('scanInstruction'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.dsh.secondaryText),
        ),
      ],
    );
  }

  Widget _manualInput(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.text('enterCode'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.text('codeHelp'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.dsh.secondaryText),
        ),
        const SizedBox(height: 22),
        TextField(
          key: const Key('pair-code-field'),
          controller: _codeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'FragmentMono',
            fontSize: 28,
            letterSpacing: 0,
            fontWeight: FontWeight.w500,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(hintText: '000000'),
          onSubmitted: (_) {
            if (_codeController.text.length == 6) {
              _handleRawValue(_codeController.text);
            }
          },
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _submitting ? null : _submitManualCode,
          child: _submitting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : Text(l10n.text('pairComputer')),
        ),
      ],
    );
  }
}

class _ErrorDetail {
  const _ErrorDetail(this.error, {this.key});

  /// Raw failure localized at render time.
  final Object? error;

  /// Catalog key for the surrounding message, with [error] as `{error}`.
  final String? key;
}

class _ScannerFramePainter extends CustomPainter {
  const _ScannerFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final inset = size.width * 0.16;
    final length = size.width * 0.12;
    final rect = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final paths = [
      Path()
        ..moveTo(rect.left, rect.top + length)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.left + length, rect.top),
      Path()
        ..moveTo(rect.right - length, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.top + length),
      Path()
        ..moveTo(rect.right, rect.bottom - length)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.right - length, rect.bottom),
      Path()
        ..moveTo(rect.left + length, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.bottom - length),
    ];
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
