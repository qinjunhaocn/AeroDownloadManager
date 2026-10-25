import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/download_task.dart';

/// Very small JSON-backed task store.
///
/// ADM uses SQLite; for a Flutter client a single atomically written JSON file
/// is plenty (tasks are small) and keeps the three target platforms free of
/// native database plugins. Segment offsets are stored verbatim, so resume
/// behaves exactly like the original.
class TaskStore {
  TaskStore(this.directory);

  final Directory directory;

  File get _file => File(p.join(directory.path, 'tasks.json'));
  File get _temp => File(p.join(directory.path, 'tasks.json.tmp'));

  Future<List<DownloadTask>> load() async {
    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      if (!await _file.exists()) return [];
      final raw = await _file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return [];
      final list = decoded['tasks'];
      if (list is! List) return [];
      final tasks = <DownloadTask>[];
      for (final item in list) {
        if (item is Map) {
          try {
            tasks.add(DownloadTask.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {
            // Skip a broken row instead of losing the whole list.
          }
        }
      }
      tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return tasks;
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<DownloadTask> tasks) async {
    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final payload = jsonEncode({
        'version': 1,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      });
      await _temp.writeAsString(payload, flush: true);
      if (await _file.exists()) {
        await _file.delete();
      }
      await _temp.rename(_file.path);
    } catch (_) {
      // Persistence must never crash the download engine.
    }
  }
}
