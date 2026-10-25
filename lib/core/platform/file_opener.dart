import 'dart:io';

import 'package:open_filex/open_filex.dart';

/// Opening files/folders works differently on each platform; keep it in one
/// place so the UI stays simple.
class FileOpener {
  static Future<bool> openFile(String path) async {
    if (path.isEmpty) return false;
    try {
      if (Platform.isAndroid) {
        final result = await OpenFilex.open(path);
        return result.type == ResultType.done;
      }
      if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [path]);
        return result.exitCode == 0;
      }
      if (Platform.isWindows) {
        final result = await Process.run('explorer.exe', [path]);
        return result.exitCode == 0 || result.exitCode == 1;
      }
      if (Platform.isMacOS) {
        final result = await Process.run('open', [path]);
        return result.exitCode == 0;
      }
    } catch (_) {
      // fall through
    }
    return false;
  }

  static Future<bool> openFolder(String path) async {
    if (path.isEmpty) return false;
    final directory = FileSystemEntity.isDirectorySync(path)
        ? path
        : File(path).parent.path;
    try {
      if (Platform.isAndroid) {
        // Android cannot open a folder directly; reveal the file instead.
        if (FileSystemEntity.isDirectorySync(path)) return false;
        final result = await OpenFilex.open(path);
        return result.type == ResultType.done;
      }
      if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [directory]);
        return result.exitCode == 0;
      }
      if (Platform.isWindows) {
        final result = await Process.run('explorer.exe', [directory]);
        return result.exitCode == 0 || result.exitCode == 1;
      }
      if (Platform.isMacOS) {
        final result = await Process.run('open', [directory]);
        return result.exitCode == 0;
      }
    } catch (_) {
      // fall through
    }
    return false;
  }
}
