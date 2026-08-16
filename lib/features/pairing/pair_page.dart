import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/analytics.dart';
import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../data/relay_service.dart';
import '../../data/device_key_store.dart';
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
  String? _error;

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
        throw const ApiException(
          'relay_mismatch',
          message: '二维码属于另一个 Relay，请检查电脑端配置。',
        );
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
        _error = userMessage(error);
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
          _error = '电脑尚未确认绑定，你可以继续等待，无需重新扫码。';
        });
        return;
      }
      ref.read(analyticsProvider).track('pair_success', {'deviceId': deviceId});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('绑定成功：${device.name}')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _waitingForConfirmation = false;
        _error = '${userMessage(error)} 已认领配对码，无需重新扫码。';
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
    setState(() => _error = '0.1.3 为保证端到端加密，只支持扫描电脑上的二维码。');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('绑定电脑')),
      body: SafeArea(
        top: false,
        child: _claimedDeviceId != null
            ? _confirmationState(context)
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.qr_code_scanner_rounded),
                        label: Text('扫码'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.dialpad_rounded),
                        label: Text('手动输入'),
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
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: DshColors.danger),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _confirmationState(BuildContext context) {
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
                color: DshColors.navy,
              ),
              const SizedBox(height: 18),
              Text('等待电脑确认', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                _waitingForConfirmation
                    ? '配对码已认领，正在等待 dsh-mobile 完成确认。'
                    : _error ?? '电脑尚未完成确认。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DshColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              if (_waitingForConfirmation)
                const CircularProgressIndicator(strokeWidth: 2)
              else ...[
                FilledButton.icon(
                  onPressed: _continueWaiting,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('继续等待'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回设备列表'),
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
          '将电脑终端中的配对二维码放入框内。',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: DshColors.secondaryText),
        ),
      ],
    );
  }

  Widget _manualInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('输入 6 位配对码', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '配对码显示在运行 npx @deepseek-ai/dsh web 的电脑终端中，5 分钟内有效。',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: DshColors.secondaryText),
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
          decoration: const InputDecoration(hintText: '000000'),
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
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('绑定电脑'),
        ),
      ],
    );
  }
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
