import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics.dart';
import '../../core/theme.dart';
import '../../data/relay_service.dart';
import '../../domain/models.dart';

enum _SessionViewState { loading, webView, deviceOffline, dshOffline, failed }

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
  _SessionViewState _state = _SessionViewState.loading;
  bool _renewingTicket = false;
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
    super.dispose();
  }

  Future<void> _openSession() async {
    ref.read(analyticsProvider).track('session_open', {
      'deviceId': widget.device.id,
    });
    if (widget.device.availability == DeviceAvailability.offline) {
      _showState(
        _SessionViewState.deviceOffline,
        analyticsEvent: 'device_offline_seen',
      );
      return;
    }
    if (widget.device.availability == DeviceAvailability.dshOffline) {
      _showState(
        _SessionViewState.dshOffline,
        analyticsEvent: 'dsh_offline_seen',
      );
      return;
    }
    final config = ref.read(appConfigProvider);
    if (config.useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _state = _SessionViewState.webView);
      return;
    }
    try {
      final ticket = await ref
          .read(relayServiceProvider)
          .createWebTicket(widget.device.id);
      final url = config.relayOrigin.replace(
        path: '/s/${widget.device.id}/',
        queryParameters: {'ticket': ticket.ticket},
      );
      if (!mounted) return;
      setState(() {
        _sessionUrl = url;
        _state = _SessionViewState.webView;
        _progress = 0;
      });
    } catch (_) {
      if (mounted) setState(() => _state = _SessionViewState.failed);
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

  Future<void> _renewTicket() async {
    if (_renewingTicket) return;
    _renewingTicket = true;
    try {
      final ticket = await ref
          .read(relayServiceProvider)
          .createWebTicket(widget.device.id);
      final config = ref.read(appConfigProvider);
      final url = config.relayOrigin.replace(
        path: '/s/${widget.device.id}/',
        queryParameters: {'ticket': ticket.ticket},
      );
      _sessionUrl = url;
      await _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url.toString())),
      );
    } catch (_) {
      _showState(_SessionViewState.failed);
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

  bool _isRelayOrigin(Uri uri) {
    final relay = ref.read(appConfigProvider).relayOrigin;
    return uri.scheme == relay.scheme &&
        uri.host == relay.host &&
        _port(uri) == _port(relay);
  }

  int _port(Uri uri) {
    if (uri.hasPort) return uri.port;
    return uri.scheme == 'https' ? 443 : 80;
  }

  Future<NavigationActionPolicy> _navigationPolicy(
    NavigationAction navigationAction,
  ) async {
    final url = navigationAction.request.url;
    if (url == null) return NavigationActionPolicy.CANCEL;
    final uri = Uri.parse(url.toString());
    if (_isRelayOrigin(uri)) return NavigationActionPolicy.ALLOW;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return NavigationActionPolicy.CANCEL;
  }

  void _handleHttpError(
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    if (request.isForMainFrame != true) return;
    switch (response.statusCode) {
      case 401:
        unawaited(_renewTicket());
      case 503:
        if (widget.device.online) {
          _showState(
            _SessionViewState.dshOffline,
            analyticsEvent: 'dsh_offline_seen',
          );
        } else {
          _showState(
            _SessionViewState.deviceOffline,
            analyticsEvent: 'device_offline_seen',
          );
        }
      default:
        if ((response.statusCode ?? 0) >= 400) {
          _showState(_SessionViewState.failed);
        }
    }
  }

  Future<void> _injectAdaptationCss() async {
    // Reserved for narrow-screen DSH patches distributed in a later release.
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
            message: '请确认电脑端的 dsh-remote 正在运行。',
            onRetry: _reload,
          ),
          _SessionViewState.dshOffline => _SessionError(
            icon: Icons.power_settings_new_rounded,
            title: 'DSH 未启动',
            message: '电脑已在线，请在电脑上运行 npx @deepseek-ai/dsh web。',
            onRetry: _reload,
          ),
          _SessionViewState.failed => _SessionError(
            icon: Icons.cloud_off_outlined,
            title: '连接失败',
            message: '请检查网络后重试。',
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
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
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
        if (_isRelayOrigin(uri)) {
          await controller.loadUrl(urlRequest: URLRequest(url: rawUrl));
        } else {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return false;
      },
    );
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
