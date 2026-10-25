import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/download_task.dart';
import '../../core/platform/file_opener.dart';
import '../../state/app_state.dart';
import '../../utils/haptics.dart';
import '../pages/editor_page.dart';
import 'task_details_sheet.dart';

/// Shared task actions used by both the Queue and Completed tabs.
class TaskActions {
  const TaskActions._();

  static Future<void> primary(
    BuildContext context,
    AppState app,
    DownloadTask task,
  ) async {
    Haptics.tap();
    switch (task.status) {
      case TaskStatus.completed:
        await openFile(context, task);
        break;
      case TaskStatus.error:
        await app.manager.retry(task);
        break;
      case TaskStatus.paused:
      case TaskStatus.queued:
        app.manager.start(task);
        break;
      case TaskStatus.connecting:
      case TaskStatus.downloading:
      case TaskStatus.waiting:
        await app.manager.pause(task);
        break;
    }
  }

  static Future<void> openFile(BuildContext context, DownloadTask task) async {
    if (task.filePath.isEmpty) return;
    if (FileSystemEntity.isDirectorySync(task.filePath)) {
      await openFolder(context, task);
      return;
    }
    final ok = await FileOpener.openFile(task.filePath);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开文件，可能尚未下载完成')));
    }
  }

  static Future<void> openFolder(
    BuildContext context,
    DownloadTask task,
  ) async {
    if (task.filePath.isEmpty) return;
    final ok = await FileOpener.openFolder(task.filePath);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开所在文件夹')));
    }
  }

  static Future<void> copyUrl(BuildContext context, DownloadTask task) async {
    Haptics.select();
    await Clipboard.setData(ClipboardData(text: task.url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('链接已复制')));
  }

  static Future<void> delete(
    BuildContext context,
    AppState app,
    DownloadTask task,
  ) async {
    final confirmed = await _confirmDelete(context, app, [task]);
    if (!confirmed) return;
    Haptics.medium();
    await app.manager.remove(task, deleteFile: true);
  }

  static Future<void> deleteMany(
    BuildContext context,
    AppState app,
    List<DownloadTask> tasks,
  ) async {
    if (tasks.isEmpty) return;
    final confirmed = await _confirmDelete(context, app, tasks);
    if (!confirmed) return;
    Haptics.medium();
    for (final task in tasks) {
      await app.manager.remove(task, deleteFile: true);
    }
    app.clearSelection();
  }

  static Future<bool> _confirmDelete(
    BuildContext context,
    AppState app,
    List<DownloadTask> tasks,
  ) async {
    if (!app.settings.confirmDelete) return true;
    final isBatch = tasks.length > 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text(
          isBatch
              ? '确定删除选中的 ${tasks.length} 个任务吗？\n已下载的文件也会被删除。'
              : '确定删除「${tasks.first.displayName}」吗？\n已下载的文件也会被删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  static Future<void> showDetails(
    BuildContext context,
    AppState app,
    DownloadTask task,
  ) async {
    Haptics.select();
    final navigator = Navigator.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskDetailsSheet(
        task: task,
        onOpen: () => openFile(context, task),
        onFolder: () => openFolder(context, task),
        onCopy: () => copyUrl(context, task),
        onEdit: task.isTorrent || task.isFinished
            ? null
            : () async {
                navigator.pop();
                if (task.status.isActive) await app.manager.pause(task);
                if (!context.mounted) return;
                await navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditorPage(task: task),
                  ),
                );
              },
        onToggle: () async {
          navigator.pop();
          if (task.status.isActive) {
            await app.manager.pause(task);
          } else {
            app.manager.start(task);
          }
        },
        onRetry: () async {
          navigator.pop();
          await app.manager.retry(task);
        },
        onDelete: () async {
          navigator.pop();
          await delete(context, app, task);
        },
      ),
    );
  }
}
