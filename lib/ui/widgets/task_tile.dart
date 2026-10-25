import 'package:flutter/material.dart';

import '../../core/models/download_task.dart';
import '../../utils/file_types.dart';
import '../../utils/formatters.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelect,
    required this.onPrimaryAction,
    required this.onMenuSelected,
  });

  final DownloadTask task;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelect;
  final VoidCallback onPrimaryAction;
  final void Function(String action) onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final category = task.category;
    final statusColor = _statusColor(scheme);
    final isActive = task.status.isActive;
    final showIndeterminate = isActive && task.total <= 0 && !task.isTorrent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerLow,
      child: InkWell(
        onTap: selectionMode ? onToggleSelect : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onToggleSelect(),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              _TypeAvatar(category: category, task: task),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!selectionMode) ...[
                          _trailingButton(context),
                          _menu(context),
                        ] else
                          const SizedBox(width: 4),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _subtitle(context, statusColor),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: showIndeterminate ? null : task.progress,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          task.total > 0
                              ? formatPercent(task.progress)
                              : (task.status == TaskStatus.completed
                                    ? '100%'
                                    : '—'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _metaLine(task),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme scheme) {
    switch (task.status) {
      case TaskStatus.error:
        return scheme.error;
      case TaskStatus.completed:
        return scheme.tertiary;
      case TaskStatus.waiting:
      case TaskStatus.queued:
        return scheme.secondary;
      case TaskStatus.paused:
        return scheme.onSurfaceVariant;
      case TaskStatus.connecting:
      case TaskStatus.downloading:
        return scheme.primary;
    }
  }

  Widget _subtitle(BuildContext context, Color statusColor) {
    final scheme = Theme.of(context).colorScheme;
    final pieces = <String>[];
    if (task.status == TaskStatus.error) {
      pieces.add(task.message.isEmpty ? '下载出错' : task.message);
    } else if (task.status == TaskStatus.waiting && task.message.isNotEmpty) {
      pieces.add(task.message);
    } else {
      pieces.add(task.status.label);
    }
    if (task.isActive && task.speed > 0) {
      pieces.add(formatSpeed(task.speed));
    }
    if (task.isActive && task.eta != null) {
      pieces.add('剩余 ${formatDuration(task.eta!.inMilliseconds)}');
    }
    final text = pieces.join(' · ');
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: task.status == TaskStatus.error
            ? scheme.error
            : scheme.onSurfaceVariant,
      ),
    );
  }

  String _metaLine(DownloadTask task) {
    if (task.isTorrent) {
      final size = task.total > 0 ? formatBytes(task.total) : '大小未知';
      return '$size · ${task.peers} 节点 · ${task.seeders} 种子';
    }
    if (task.total > 0) {
      final threads = task.segments.isEmpty ? 0 : task.segments.length;
      final suffix = threads > 1 ? ' · $threads 线程' : '';
      return '${formatBytes(task.downloaded)} / ${formatBytes(task.total)}$suffix';
    }
    return '${formatBytes(task.downloaded)} 已下载';
  }

  Widget _trailingButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var icon = Icons.pause_rounded;
    VoidCallback? callback = onPrimaryAction;
    var tooltip = '暂停';
    switch (task.status) {
      case TaskStatus.completed:
        icon = Icons.open_in_new_rounded;
        callback = () => onMenuSelected('open');
        tooltip = '打开文件';
        break;
      case TaskStatus.error:
        icon = Icons.refresh_rounded;
        callback = onPrimaryAction;
        tooltip = '重试';
        break;
      case TaskStatus.paused:
      case TaskStatus.queued:
        icon = Icons.play_arrow_rounded;
        callback = onPrimaryAction;
        tooltip = '继续';
        break;
      case TaskStatus.waiting:
        icon = Icons.pause_rounded;
        callback = onPrimaryAction;
        tooltip = '暂停';
        break;
      case TaskStatus.connecting:
      case TaskStatus.downloading:
        icon = Icons.pause_rounded;
        callback = onPrimaryAction;
        tooltip = '暂停';
        break;
    }
    return IconButton(
      tooltip: tooltip,
      iconSize: 20,
      color: scheme.onSurfaceVariant,
      onPressed: callback,
      icon: Icon(icon),
    );
  }

  Widget _menu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '更多',
      iconSize: 20,
      onSelected: onMenuSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'details', child: Text('详情')),
        const PopupMenuItem(value: 'open', child: Text('打开文件')),
        const PopupMenuItem(value: 'folder', child: Text('打开所在文件夹')),
        const PopupMenuItem(value: 'copy', child: Text('复制链接')),
        if (task.status == TaskStatus.error)
          const PopupMenuItem(value: 'retry', child: Text('重试')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('删除')),
      ],
    );
  }
}

class _TypeAvatar extends StatelessWidget {
  const _TypeAvatar({required this.category, required this.task});

  final DownloadCategory category;
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = task.isTorrent ? scheme.tertiary : category.color;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        task.isTorrent
            ? Icons.hub_outlined
            : task.isActive
            ? Icons.downloading_rounded
            : category.icon,
        color: color,
        size: 24,
      ),
    );
  }
}
