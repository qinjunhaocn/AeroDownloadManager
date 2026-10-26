import 'dart:io';

class SearchEngine {
  const SearchEngine({
    required this.id,
    required this.name,
    required this.template,
  });

  final String id;
  final String name;

  /// Contains `{query}` where the encoded keywords go.
  final String template;

  String urlFor(String query) =>
      template.replaceFirst('{query}', Uri.encodeQueryComponent(query));
}

class SearchEngines {
  const SearchEngines._();

  static const List<SearchEngine> all = [
    SearchEngine(
      id: 'bing',
      name: '必应',
      template: 'https://www.bing.com/search?q={query}',
    ),
    SearchEngine(
      id: 'google',
      name: 'Google',
      template: 'https://www.google.com/search?q={query}',
    ),
    SearchEngine(
      id: 'baidu',
      name: '百度',
      template: 'https://www.baidu.com/s?wd={query}',
    ),
    SearchEngine(
      id: 'duckduckgo',
      name: 'DuckDuckGo',
      template: 'https://duckduckgo.com/?q={query}',
    ),
  ];

  static SearchEngine byId(String id) {
    return all.firstWhere((engine) => engine.id == id, orElse: () => all.first);
  }

  static String nameOf(String id) => byId(id).name;

  static String searchUrl(String id, String query) => byId(id).urlFor(query);
}

/// Adds a scheme when the user typed a bare domain/IP, and leaves existing
/// schemes and magnet links untouched.
String normalizeUrlInput(String input) {
  final value = input.trim();
  if (value.isEmpty) return value;
  if (value.contains('://') || value.toLowerCase().startsWith('magnet:')) {
    return value;
  }
  final authority = value.split('/').first;
  final host = authority.split(':').first;
  final isLocal =
      host == 'localhost' ||
      (InternetAddress.tryParse(host)?.isLoopback ?? false) ||
      host.startsWith('10.') ||
      host.startsWith('192.168.') ||
      RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host);
  return '${isLocal ? 'http' : 'https'}://$value';
}
