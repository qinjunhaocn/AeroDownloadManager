import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';
import '../../utils/haptics.dart';
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
  final FocusNode _urlFocus = FocusNode();
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loading = false;
  String _currentUrl = '';
  bool _hasUrl = false;
  bool _creatingWebView = false;
  String _pendingUrl = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialUrl?.trim() ?? '';
    _urlController = TextEditingController(text: initial);
    if (initial.isNotEmpty) {
      _pendingUrl = _normalize(initial);
      _currentUrl = _pendingUrl;
      _hasUrl = true;
    }
    _urlFocus.addListener(() {
      if (_urlFocus.hasFocus) {
        // Let the text field apply its own cursor placement first, then select
        // the whole address (desktop browser behaviour).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _urlFocus.hasFocus) _selectAllUrl();
        });
      }
    });
  }

  /// Tapping the address bar selects everything, matching desktop browsers.
  void _selectAllUrl() {
    final text = _urlController.text;
    if (text.isEmpty) return;
    _urlController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }

  @override
  void dispose() {
    _urlFocus.dispose();
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
    Haptics.select();
    _urlController.text = url;
    _urlController.selection = TextSelection.collapsed(offset: url.length);
    if (!_webViewSupported) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    if (!_hasUrl) {
      if (_creatingWebView) return;
      _creatingWebView = true;
      setState(() {
        _pendingUrl = url;
        _currentUrl = url;
        _loading = true;
        _progress = 0;
      });
      // Let the loading state paint before the platform WebView is created;
      // creating it synchronously on the tap frame is what made the first
      // navigation feel like a freeze.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _hasUrl = true;
          _creatingWebView = false;
        });
      });
      return;
    }
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> _currentPageUrl() async {
    if (!_webViewSupported) return;
    final controller = _controller;
    if (controller == null) return;
    final url = await controller.getUrl();
    if (url != null) _currentUrl = url.toString();
  }

  Future<void> _addCurrentPage() async {
    Haptics.tap();
    await _currentPageUrl();
    if (!mounted) return;
    final url = _currentUrl;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先打开一个网页')));
      return;
    }
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
                  focusNode: _urlFocus,
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
            onOpened: Haptics.select,
            onSelected: (value) async {
              Haptics.select();
              final home = context.read<AppState>().settings.browserHome;
              switch (value) {
                case 'home':
                  await _go(home);
                  break;
                case 'external':
                  final external = _normalize(_urlController.text);
                  if (external.isNotEmpty) {
                    await launchUrl(
                      Uri.parse(external),
                      mode: LaunchMode.externalApplication,
                    );
                  }
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
          ? (_hasUrl
                ? InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(_pendingUrl)),
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
                : (_loading
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : const SizedBox.expand()))
          : _DesktopFallback(
              urlController: _urlController,
              onGo: _go,
              onAddDownload: () => showAddDownloadSheet(
                context,
                initialUrl: _urlController.text,
              ),
            ),
      bottomNavigationBar: _webViewSupported && _hasUrl
          ? BottomAppBar(
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    tooltip: '后退',
                    onPressed: () {
                      Haptics.select();
                      _controller?.goBack();
                    },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  IconButton(
                    tooltip: '前进',
                    onPressed: () {
                      Haptics.select();
                      _controller?.goForward();
                    },
                    icon: const Icon(Icons.arrow_forward_ios_rounded),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: () {
                      Haptics.select();
                      _controller?.reload();
                    },
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
