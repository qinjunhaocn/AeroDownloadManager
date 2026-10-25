import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';
import '../widgets/add_download_sheet.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  static bool get _webViewSupported => Platform.isAndroid || Platform.isWindows;

  late final TextEditingController _urlController;
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loading = false;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final url =
        widget.initialUrl ??
        (state.settings.browserHome.isNotEmpty
            ? state.settings.browserHome
            : 'https://www.google.com');
    _urlController = TextEditingController(text: url);
    _currentUrl = url;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String _normalize(String input) {
    var value = input.trim();
    if (value.isEmpty) return '';
    if (!value.contains('://')) value = 'https://$value';
    return value;
  }

  Future<void> _go(String input) async {
    final url = _normalize(input);
    if (url.isEmpty) return;
    _urlController.text = url;
    if (!_webViewSupported) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> _currentPageUrl() async {
    if (!_webViewSupported) return;
    final controller = _controller;
    if (controller == null) return;
    final url = await controller.getUrl();
    if (url != null) _currentUrl = url.toString();
  }

  Future<void> _addCurrentPage() async {
    await _currentPageUrl();
    if (!mounted) return;
    final url = _currentUrl;
    if (url.isEmpty) return;
    await showAddDownloadSheet(context, initialUrl: url);
  }

  Future<void> _handleDownload(DownloadStartRequest request) async {
    final url = request.url.toString();
    if (url.isEmpty) return;
    String cookie = '';
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(url),
      );
      cookie = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    } catch (_) {
      // ignore
    }
    if (!mounted) return;
    try {
      await context.read<AppState>().manager.addHttp(
        url: url,
        name: request.suggestedFilename ?? '',
        userAgent: request.userAgent ?? '',
        referer: _currentUrl,
        cookie: cookie,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已从浏览器加入下载')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  textInputAction: TextInputAction.go,
                  style: Theme.of(context).textTheme.bodySmall,
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '输入网址',
                  ),
                  onSubmitted: _go,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: '打开',
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => _go(_urlController.text),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final home = context.read<AppState>().settings.browserHome;
              switch (value) {
                case 'home':
                  await _go(home);
                  break;
                case 'external':
                  await launchUrl(
                    Uri.parse(_normalize(_urlController.text)),
                    mode: LaunchMode.externalApplication,
                  );
                  break;
                case 'download':
                  await _addCurrentPage();
                  break;
                case 'clear':
                  _urlController.clear();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'download', child: Text('将此页加入下载')),
              PopupMenuItem(value: 'external', child: Text('用系统浏览器打开')),
              PopupMenuItem(value: 'clear', child: Text('清空地址栏')),
            ],
          ),
        ],
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress <= 0 ? null : _progress,
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: _webViewSupported
          ? InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(_normalize(_urlController.text)),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                supportZoom: true,
                mediaPlaybackRequiresUserGesture: false,
                useHybridComposition: true,
                transparentBackground: false,
                allowFileAccess: false,
                allowContentAccess: false,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _loading = true;
                  _progress = 0;
                  if (url != null) {
                    _currentUrl = url.toString();
                    _urlController.text = _currentUrl;
                  }
                });
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                  _loading = progress < 100;
                });
              },
              onLoadStop: (controller, url) async {
                setState(() => _loading = false);
                if (url != null) {
                  _currentUrl = url.toString();
                  _urlController.text = _currentUrl;
                }
              },
              onDownloadStartRequest: (controller, request) {
                _handleDownload(request);
              },
            )
          : _DesktopFallback(
              urlController: _urlController,
              onGo: _go,
              onAddDownload: () => showAddDownloadSheet(
                context,
                initialUrl: _urlController.text,
              ),
            ),
      bottomNavigationBar: _webViewSupported
          ? BottomAppBar(
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    tooltip: '后退',
                    onPressed: () => _controller?.goBack(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  IconButton(
                    tooltip: '前进',
                    onPressed: () => _controller?.goForward(),
                    icon: const Icon(Icons.arrow_forward_ios_rounded),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: () => _controller?.reload(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: '下载当前页',
                    onPressed: _addCurrentPage,
                    icon: const Icon(Icons.download_rounded),
                  ),
                  IconButton(
                    tooltip: '用系统浏览器打开',
                    onPressed: () => launchUrl(
                      Uri.parse(_normalize(_urlController.text)),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _DesktopFallback extends StatelessWidget {
  const _DesktopFallback({
    required this.urlController,
    required this.onGo,
    required this.onAddDownload,
  });

  final TextEditingController urlController;
  final Future<void> Function(String) onGo;
  final VoidCallback onAddDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.travel_explore_rounded,
                size: 72,
                color: scheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                'Linux 内置浏览器',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Linux 版暂未集成 WebView 组件。你仍可以使用系统浏览器打开网页，'
                '或直接把地址加入 Aero 下载。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => onGo(urlController.text),
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('用系统浏览器打开'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onAddDownload,
                icon: const Icon(Icons.download_rounded),
                label: const Text('下载此链接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
