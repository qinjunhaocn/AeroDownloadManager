import 'package:flutter/material.dart';

import '../../core/models/download_task.dart';
import '../../utils/formatters.dart';

class TaskDetailsSheet extends StatelessWidget {
  const TaskDetailsSheet({
    super.key,
    required this.task,
    required this.onOpen,
    required this.onFolder,
    required this.onCopy,
    required this.onEdit,
    required this.onToggle,
    required this.onRetry,
    required this.onDelete,
  });

  final DownloadTask task;
  final Future<void> Function() onOpen;
  final Future<void> Function() onFolder;
  final Future<void> Function() onCopy;
  final Future<void> Function()? onEdit;
  final Future<void> Function() onToggle;
  final Future<void> Function() onRetry;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final category = task.category;
    final isActive = task.status.isActive;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  task.isTorrent ? Icons.hub_outlined : category.icon,
                  color: category.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.displayName,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${task.status.label} · ${formatPercent(task.progress)}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: task.progress, minHeight: 6),
          ),
          const SizedBox(height: 16),
          _kv(context, '大小', task.total > 0 ? formatBytes(task.total) : '未知'),
          _kv(context, '已下载', formatBytes(task.downloaded)),
          if (task.isTorrent) ...[
            _kv(context, '速度', formatSpeed(task.speed)),
            _kv(context, '上传', formatSpeed(task.uploadSpeed)),
            _kv(context, '节点 / 种子', '${task.peers} / ${task.seeders}'),
            _kv(context, 'Info hash', task.infoHash),
          ] else ...[
            _kv(context, '速度', formatSpeed(task.speed)),
            if (task.eta != null)
              _kv(context, '剩余时间', formatDuration(task.eta!.inMilliseconds)),
            _kv(context, '线程', '${task.segments.length}'),
            _kv(context, 'Range', task.noRange ? '已禁用（单连接）' : '启用'),
            if (task.checksum.isNotEmpty)
              _kv(context, '校验', task.checksumType.toUpperCase()),
          ],
          _kv(context, '保存位置', task.filePath),
          _kv(
            context,
            '创建时间',
            formatDateTime(DateTime.fromMillisecondsSinceEpoch(task.createdAt)),
          ),
          if (task.finishedAt != null)
            _kv(
              context,
              '完成时间',
              formatDateTime(
                DateTime.fromMillisecondsSinceEpoch(task.finishedAt!),
              ),
            ),
          if (task.message.isNotEmpty) _kv(context, '状态信息', task.message),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => onToggle(),
                icon: Icon(
                  isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(isActive ? '暂停' : '继续'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpen(),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('打开'),
              ),
              OutlinedButton.icon(
                onPressed: () => onFolder(),
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('文件夹'),
              ),
              OutlinedButton.icon(
                onPressed: () => onCopy(),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('复制链接'),
              ),
              if (onEdit != null)
                OutlinedButton.icon(
                  onPressed: () => onEdit!(),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
              if (task.status == TaskStatus.error)
                OutlinedButton.icon(
                  onPressed: () => onRetry(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              OutlinedButton.icon(
                onPressed: () => onDelete(),
                style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String key, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              key,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
