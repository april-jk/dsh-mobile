import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics.dart';
import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../data/device_key_store.dart';
import '../../data/relay_service.dart';
import '../../domain/models.dart';
import 'local_session_proxy.dart';
import 'session_policy.dart';

enum _SessionViewState {
  loading,
  webView,
  deviceOffline,
  dshOffline,
  tunnelTimeout,
  encryptionRequired,
  failed,
}

class SessionWebViewPage extends ConsumerStatefulWidget {
  const SessionWebViewPage({super.key, required this.device});

  final Device device;

  @override
  ConsumerState<SessionWebViewPage> createState() => _SessionWebViewPageState();
}

class _SessionWebViewPageState extends ConsumerState<SessionWebViewPage> {
  final _openedAt = DateTime.now();
  InAppWebViewController? _controller;
  Uri? _sessionUrl;
  LocalSessionProxy? _proxy;
  _SessionViewState _state = _SessionViewState.loading;
  bool _renewingTicket = false;
  final _ticketRenewalGuard = TicketRenewalGuard();
  DateTime? _webLoadStartedAt;
  bool _readyReported = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_openSession);
  }

  @override
  void dispose() {
    ref.read(analyticsProvider).track('session_duration', {
      'deviceId': widget.device.id,
      'seconds': DateTime.now().difference(_openedAt).inSeconds,
    });
    unawaited(_proxy?.close());
    super.dispose();
  }

  Future<Uri> _createSecureSession() async {
    final key = await ref.read(deviceKeyStoreProvider).read(widget.device.id);
    if (key == null) {
      throw const ApiException('e2ee_required', message: '这台电脑需要重新扫码以建立加密密钥。');
    }
    final ticket = await ref
        .read(relayServiceProvider)
        .createWebTicket(widget.device.id);
    final previous = _proxy;
    _proxy = null;
    await previous?.close();
    final proxy = await LocalSessionProxy.start(ticket: ticket, masterKey: key);
    if (!mounted) {
      await proxy.close();
      throw StateError('session page disposed');
    }
    _proxy = proxy;
    return proxy.startUrl;
  }

  void _showOpenError(Object error) {
    if (!mounted) return;
    final state = error is ApiException
        ? switch (error.code) {
            'e2ee_required' ||
            'e2ee_pairing_required' => _SessionViewState.encryptionRequired,
            'device_offline' => _SessionViewState.deviceOffline,
            'dsh_offline' => _SessionViewState.dshOffline,
            'tunnel_timeout' => _SessionViewState.tunnelTimeout,
            _ => _SessionViewState.failed,
          }
        : _SessionViewState.failed;
    setState(() => _state = state);
  }

  Future<void> _openSession() async {
    ref.read(analyticsProvider).track('session_open', {
      'deviceId': widget.device.id,
    });
    final config = ref.read(appConfigProvider);
    if (config.useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _state = _SessionViewState.webView);
      return;
    }
    try {
      final url = await _createSecureSession();
      if (!mounted) return;
      setState(() {
        _sessionUrl = url;
        _state = _SessionViewState.webView;
        _progress = 0;
        _ticketRenewalGuard.reset();
        _webLoadStartedAt = DateTime.now();
        _readyReported = false;
      });
    } catch (error) {
      _showOpenError(error);
    }
  }

  void _showState(_SessionViewState state, {String? analyticsEvent}) {
    if (!mounted) return;
    setState(() => _state = state);
    if (analyticsEvent != null) {
      ref.read(analyticsProvider).track(analyticsEvent, {
        'deviceId': widget.device.id,
      });
    }
  }

  Future<void> _reload({bool manual = false}) async {
    if (manual) {
      ref.read(analyticsProvider).track('webview_reload', {
        'deviceId': widget.device.id,
      });
    }
    final config = ref.read(appConfigProvider);
    if (config.useMock) {
      setState(() => _state = _SessionViewState.loading);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => _state = _SessionViewState.webView);
      return;
    }
    if (_state == _SessionViewState.webView && _controller != null && !manual) {
      await _renewTicket();
      return;
    }
    setState(() => _state = _SessionViewState.loading);
    await _openSession();
  }

  Future<void> _renewTicket({bool afterUnauthorized = false}) async {
    if (_renewingTicket) return;
    if (afterUnauthorized && !_ticketRenewalGuard.take()) {
      _showState(_SessionViewState.failed);
      return;
    }
    _renewingTicket = true;
    try {
      final url = await _createSecureSession();
      _sessionUrl = url;
      _webLoadStartedAt = DateTime.now();
      _readyReported = false;
      await _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url.toString())),
      );
    } catch (error) {
      _showOpenError(error);
    } finally {
      _renewingTicket = false;
    }
  }

  Future<void> _handleBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<NavigationActionPolicy> _navigationPolicy(
    NavigationAction navigationAction,
  ) async {
    final url = navigationAction.request.url;
    if (url == null) return NavigationActionPolicy.CANCEL;
    final uri = Uri.parse(url.toString());
    final localOrigin = _proxy?.origin;
    if (localOrigin == null) return NavigationActionPolicy.CANCEL;
    return switch (classifySessionNavigation(uri, localOrigin)) {
      SessionNavigation.session => NavigationActionPolicy.ALLOW,
      SessionNavigation.external => _openExternal(uri),
      SessionNavigation.blocked => NavigationActionPolicy.CANCEL,
    };
  }

  Future<NavigationActionPolicy> _openExternal(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return NavigationActionPolicy.CANCEL;
  }

  Future<void> _handleHttpError(
    WebResourceRequest request,
    WebResourceResponse response,
  ) async {
    if (request.isForMainFrame != true) return;
    switch (sessionHttpAction(response.statusCode)) {
      case SessionHttpAction.renewTicket:
        await _renewTicket(afterUnauthorized: true);
      case SessionHttpAction.refreshDeviceStatus:
        await _refreshDeviceStatus();
      case SessionHttpAction.tunnelTimeout:
        _showState(_SessionViewState.tunnelTimeout);
      case SessionHttpAction.failed:
        _showState(_SessionViewState.failed);
      case SessionHttpAction.ignore:
        return;
    }
  }

  Future<void> _refreshDeviceStatus() async {
    try {
      final devices = await ref.read(relayServiceProvider).listDevices();
      switch (latestDeviceAvailability(devices, widget.device.id)) {
        case DeviceAvailability.offline:
          _showState(
            _SessionViewState.deviceOffline,
            analyticsEvent: 'device_offline_seen',
          );
        case DeviceAvailability.dshOffline:
          _showState(
            _SessionViewState.dshOffline,
            analyticsEvent: 'dsh_offline_seen',
          );
        case DeviceAvailability.online:
        case null:
          _showState(_SessionViewState.failed);
      }
    } catch (_) {
      _showState(_SessionViewState.failed);
    }
  }

  Future<void> _injectAdaptationCss() async {
    await _controller?.injectCSSCode(source: dshMobileFontCss);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            widget.device.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: () => _reload(manual: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 6),
          ],
          bottom: _state == _SessionViewState.webView && _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress / 100,
                    minHeight: 2,
                  ),
                )
              : null,
        ),
        body: switch (_state) {
          _SessionViewState.loading => const _SessionSkeleton(),
          _SessionViewState.webView => _sessionContent(),
          _SessionViewState.deviceOffline => _SessionError(
            icon: Icons.computer_outlined,
            title: '电脑不在线',
            message: '请确认电脑端已运行 npx @deepseek-ai/dsh web，dsh-mobile 会随它自动启停。',
            onRetry: _reload,
          ),
          _SessionViewState.dshOffline => _SessionError(
            icon: Icons.power_settings_new_rounded,
            title: 'DSH 未启动',
            message: '电脑已在线，请在电脑上运行 npx @deepseek-ai/dsh web。',
            onRetry: _reload,
          ),
          _SessionViewState.tunnelTimeout => _SessionError(
            icon: Icons.timer_outlined,
            title: '连接超时',
            message: 'Relay 等待电脑响应超时，请检查网络后重试。',
            onRetry: _reload,
          ),
          _SessionViewState.encryptionRequired => _SessionError(
            icon: Icons.qr_code_2_rounded,
            title: '需要重新扫码',
            message: '0.1.3 已启用端到端加密，请移除旧配对后扫描电脑上的新二维码。',
            onRetry: _reload,
          ),
          _SessionViewState.failed => _SessionError(
            icon: Icons.cloud_off_outlined,
            title: '暂时无法连接',
            message: '无法确认电脑或 DSH 的当前状态，请稍后重试。',
            onRetry: _reload,
          ),
        },
      ),
    );
  }

  Widget _sessionContent() {
    final config = ref.read(appConfigProvider);
    if (config.useMock) return const _MockSession();
    final url = _sessionUrl;
    if (url == null) return const _SessionSkeleton();
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url.toString())),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: dshFontBootstrapScript(),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        cacheEnabled: true,
        cacheMode: CacheMode.LOAD_DEFAULT,
        useShouldOverrideUrlLoading: true,
        supportZoom: false,
        mediaPlaybackRequiresUserGesture: false,
      ),
      onWebViewCreated: (controller) => _controller = controller,
      shouldOverrideUrlLoading: (_, action) => _navigationPolicy(action),
      onProgressChanged: (_, progress) {
        if (mounted) setState(() => _progress = progress);
      },
      onLoadStop: (_, _) async {
        if (mounted) setState(() => _progress = 100);
        await _injectAdaptationCss();
        _reportWebViewReady();
      },
      onReceivedHttpError: (_, request, response) =>
          _handleHttpError(request, response),
      onReceivedError: (_, request, _) {
        if (request.isForMainFrame == true) {
          _showState(_SessionViewState.failed);
        }
      },
      onCreateWindow: (controller, action) async {
        final rawUrl = action.request.url;
        if (rawUrl == null) return false;
        final uri = Uri.parse(rawUrl.toString());
        final localOrigin = _proxy?.origin;
        if (localOrigin == null) return false;
        switch (classifySessionNavigation(uri, localOrigin)) {
          case SessionNavigation.session:
            await controller.loadUrl(urlRequest: URLRequest(url: rawUrl));
          case SessionNavigation.external:
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          case SessionNavigation.blocked:
            break;
        }
        return false;
      },
    );
  }

  void _reportWebViewReady() {
    final startedAt = _webLoadStartedAt;
    if (_readyReported || startedAt == null) return;
    _readyReported = true;
    ref.read(analyticsProvider).track('session_webview_ready', {
      'deviceId': widget.device.id,
      'milliseconds': DateTime.now().difference(startedAt).inMilliseconds,
    });
  }
}

class _SessionSkeleton extends StatelessWidget {
  const _SessionSkeleton();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DshColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 36, decoration: _placeholder()),
            const SizedBox(height: 20),
            Container(height: 14, width: 210, decoration: _placeholder()),
            const SizedBox(height: 10),
            Container(height: 14, decoration: _placeholder()),
            const SizedBox(height: 10),
            Container(height: 14, width: 260, decoration: _placeholder()),
          ],
        ),
      ),
    );
  }

  BoxDecoration _placeholder() => BoxDecoration(
    color: DshColors.softSurface,
    borderRadius: BorderRadius.circular(7),
  );
}

class _SessionError extends StatelessWidget {
  const _SessionError({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: DshColors.secondaryText),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DshColors.secondaryText,
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockSession extends StatelessWidget {
  const _MockSession();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DshColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: DshColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: DshColors.accent,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Mock Relay 已连接',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '切换到真实 Relay 构建后，此处将加载电脑上的 DSH Web UI。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DshColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
