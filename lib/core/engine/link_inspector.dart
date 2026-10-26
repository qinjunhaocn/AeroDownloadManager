import 'dart:io';

import '../../utils/file_types.dart';
import '../../utils/search_engines.dart';
import 'http_transport.dart';

enum LinkKind { download, browser, torrent, unknown }

class LinkInspection {
  const LinkInspection(this.kind, this.message);

  final LinkKind kind;
  final String message;
}

/// Best-effort decision between "this is a web page" and "this is a file".
///
/// Obvious file extensions are resolved locally; everything else gets a tiny
/// ranged request so the server's `Content-Type` / `Content-Disposition` can
/// tell us whether the address is an HTML page or a download.
class LinkInspector {
  const LinkInspector._();

  static const Set<String> _browserExtensions = {
    'html',
    'htm',
    'xhtml',
    'shtml',
    'php',
    'asp',
    'aspx',
    'jsp',
    'jspx',
    'do',
    'action',
    'cgi',
  };

  static Future<LinkInspection> inspect(
    String input, {
    String userAgent = '',
    String proxy = '',
  }) async {
    final value = normalizeUrlInput(input);
    if (value.isEmpty) {
      return const LinkInspection(LinkKind.unknown, '请输入链接');
    }
    if (value.toLowerCase().startsWith('magnet:')) {
      return const LinkInspection(LinkKind.torrent, '检测到磁力链接');
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return const LinkInspection(LinkKind.unknown, '无法识别链接格式，仍可尝试下载');
    }

    final extension = _extensionOf(uri);
    if (extension == 'torrent') {
      return const LinkInspection(LinkKind.torrent, '检测到种子文件链接');
    }
    if (extension.isNotEmpty &&
        !_browserExtensions.contains(extension) &&
        categoryForName('file.$extension') != DownloadCategory.other) {
      return const LinkInspection(LinkKind.download, '检测到可下载文件');
    }
    if ((uri.path.isEmpty || uri.path == '/') && uri.query.isEmpty) {
      return const LinkInspection(LinkKind.browser, '检测到网页链接');
    }

    try {
      final result = await HttpTransport.get(
        uri: uri,
        headers: {
          HttpHeaders.rangeHeader: 'bytes=0-0',
          HttpHeaders.acceptHeader: '*/*',
          if (userAgent.isNotEmpty) HttpHeaders.userAgentHeader: userAgent,
        },
        timeoutSec: 5,
        proxy: proxy,
      ).timeout(const Duration(seconds: 8));
      final status = result.response.statusCode;
      final mime =
          result.response.headers.contentType?.mimeType.toLowerCase() ?? '';
      final disposition =
          (result.response.headers.value('content-disposition') ?? '')
              .toLowerCase();
      // Do not read the body: a server that ignores Range may start streaming
      // the whole file.
      result.client.close(force: true);

      if (status >= 400) {
        return LinkInspection(LinkKind.unknown, '服务器返回 HTTP $status，仍可尝试下载');
      }
      if (disposition.contains('attachment')) {
        return const LinkInspection(LinkKind.download, '检测到附件下载');
      }
      if (mime == 'application/x-bittorrent') {
        return const LinkInspection(LinkKind.torrent, '检测到种子文件');
      }
      if (mime.startsWith('text/html') || mime == 'application/xhtml+xml') {
        return const LinkInspection(LinkKind.browser, '检测到网页链接');
      }
      if (mime.isNotEmpty) {
        return const LinkInspection(LinkKind.download, '检测到可下载文件');
      }
      return const LinkInspection(LinkKind.unknown, '无法确认链接类型，仍可尝试下载');
    } catch (_) {
      return const LinkInspection(LinkKind.unknown, '无法连接服务器，仍可尝试下载');
    }
  }

  static String _extensionOf(Uri uri) {
    String candidate = '';
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) candidate = segments.last;
    for (final key in const ['filename', 'file', 'name', 'fn']) {
      final value = uri.queryParameters[key];
      if (value != null && value.trim().isNotEmpty) {
        candidate = value.trim();
        break;
      }
    }
    try {
      candidate = Uri.decodeComponent(candidate);
    } catch (_) {
      // keep raw value
    }
    final dot = candidate.lastIndexOf('.');
    if (dot < 0 || dot == candidate.length - 1) return '';
    return candidate.substring(dot + 1).toLowerCase();
  }
}
