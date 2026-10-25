library;

/// Minimal `dart_ipify` compatible API used by `dtorrent_task`.
///
/// The original package pins `sdk: <3.0.0`, which prevents resolving it on
/// modern Dart SDKs. This local fork keeps the same public surface and simply
/// asks ipify for the public address over HTTPS.
import 'dart:convert';
import 'dart:io';

class Ipify {
  static Future<String> ipv4() async =>
      _query(Uri.parse('https://api.ipify.org?format=json'));

  static Future<String> ipv6() async =>
      _query(Uri.parse('https://api6.ipify.org?format=json'));

  static Future<String> _query(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(uri);
      final response =
          await request.close().timeout(const Duration(seconds: 5));
      final body = await response.transform(utf8.decoder).join();
      final decoded = json.decode(body);
      if (decoded is Map && decoded['ip'] is String) {
        return decoded['ip'] as String;
      }
      return '';
    } catch (_) {
      return '';
    } finally {
      client.close(force: true);
    }
  }
}
