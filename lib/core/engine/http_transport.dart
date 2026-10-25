import 'dart:async';
import 'dart:io';

/// Thrown by the engine for expected, user-facing failures.
class DownloadException implements Exception {
  DownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HttpResult {
  HttpResult({
    required this.client,
    required this.response,
    required this.finalUri,
    required this.cookie,
  });

  final HttpClient client;
  final HttpClientResponse response;
  final Uri finalUri;
  final String? cookie;

  void close() {
    try {
      response
          .detachSocket()
          .then((socket) => socket.destroy())
          .catchError((_) {});
    } catch (_) {
      // ignore
    }
    client.close(force: true);
  }
}

/// Tiny HTTP transport that mirrors ADM's approach: manual redirects, explicit
/// `Range`, no transparent decompression, optional "accept any certificate"
/// (the original app uses a trust-all X509TrustManager) and an optional proxy.
class HttpTransport {
  static const int _maxRedirects = 10;

  static Future<HttpResult> get({
    required Uri uri,
    Map<String, String> headers = const {},
    int timeoutSec = 16,
    bool trustAll = true,
    String proxy = '',
    String cookie = '',
  }) async {
    final client = HttpClient()
      ..connectionTimeout = Duration(seconds: timeoutSec)
      ..autoUncompress = false
      ..idleTimeout = const Duration(seconds: 5);
    if (trustAll) {
      client.badCertificateCallback = (cert, host, port) => true;
    }
    final proxyValue = _normalizeProxy(proxy);
    if (proxyValue != null) {
      client.findProxy = (_) => proxyValue;
    }

    var current = uri;
    String? lastCookie;
    try {
      for (var hop = 0; hop <= _maxRedirects; hop++) {
        final request = await client
            .getUrl(current)
            .timeout(Duration(seconds: timeoutSec));
        request
          ..followRedirects = false
          ..persistentConnection = false;
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        headers.forEach((key, value) {
          if (value.isNotEmpty) request.headers.set(key, value);
        });
        final mergedCookie = _mergeCookie(cookie, lastCookie);
        if (mergedCookie.isNotEmpty) {
          request.headers.set(HttpHeaders.cookieHeader, mergedCookie);
        }

        final response = await request.close().timeout(
          Duration(seconds: timeoutSec),
        );
        final cookies = response.headers[HttpHeaders.setCookieHeader];
        if (cookies != null && cookies.isNotEmpty) {
          final raw = cookies.first;
          final semicolon = raw.indexOf(';');
          lastCookie = (semicolon > 0 ? raw.substring(0, semicolon) : raw)
              .trim();
        }

        if (_isRedirect(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>().catchError((_) {});
          if (location == null || location.isEmpty) {
            throw DownloadException(
              '重定向缺少 Location（HTTP ${response.statusCode}）',
            );
          }
          current = current.resolve(location.trim());
          continue;
        }

        // Final response. Do not use HttpResult.close() for regular bodies.
        return HttpResult(
          client: client,
          response: response,
          finalUri: current,
          cookie: lastCookie,
        );
      }
      throw DownloadException('重定向次数过多');
    } catch (error) {
      client.close(force: true);
      if (error is DownloadException) rethrow;
      if (error is TimeoutException) {
        throw DownloadException('连接超时');
      }
      if (error is SocketException) {
        throw DownloadException('无法连接到服务器（${error.message}）');
      }
      if (error is HandshakeException) {
        throw DownloadException('SSL 握手失败');
      }
      if (error is HttpException) {
        throw DownloadException(error.message);
      }
      throw DownloadException('网络错误：$error');
    }
  }

  static bool _isRedirect(int code) =>
      code == HttpStatus.movedPermanently ||
      code == HttpStatus.found ||
      code == HttpStatus.seeOther ||
      code == HttpStatus.temporaryRedirect ||
      code == HttpStatus.permanentRedirect;

  static String _mergeCookie(String a, String? b) {
    if (b == null || b.isEmpty) return a;
    if (a.isEmpty) return b;
    // Keep the first cookie name/value, mirroring ADM's single-cookie model.
    return a;
  }

  static String? _normalizeProxy(String proxy) {
    final trimmed = proxy.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toUpperCase().startsWith('PROXY ') ||
        trimmed.toUpperCase().startsWith('DIRECT')) {
      return trimmed;
    }
    if (trimmed.toLowerCase().startsWith('socks')) {
      // dart:io only supports HTTP proxies; ignore SOCKS entries.
      return null;
    }
    return 'PROXY $trimmed';
  }
}

String describeHttpStatus(int code, String? contentType) {
  switch (code) {
    case 400:
      return '请求错误（HTTP 400）';
    case 401:
      return '需要身份验证（HTTP 401）';
    case 403:
      return '访问被拒绝（HTTP 403）';
    case 404:
      return '文件不存在（HTTP 404）';
    case 405:
      return '方法不被允许（HTTP 405）';
    case 410:
      return '链接已失效（HTTP 410）';
    case 416:
      return '范围请求无效（HTTP 416）';
    case 429:
      return '请求过于频繁（HTTP 429）';
    case 500:
      return '服务器内部错误（HTTP 500）';
    case 502:
      return '网关错误（HTTP 502）';
    case 503:
      return '服务不可用（HTTP 503）';
    case 504:
      return '网关超时（HTTP 504）';
    default:
      if (code >= 500) return '服务器错误（HTTP $code）';
      if (code >= 400) return '客户端错误（HTTP $code）';
      return 'HTTP $code';
  }
}
