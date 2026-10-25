import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/download_task.dart';
import '../../state/app_state.dart';
import '../../utils/haptics.dart';
import '../widgets/add_download_sheet.dart';
import '../widgets/aero_drawer.dart';
import '../widgets/empty_tasks.dart';
import '../widgets/task_actions.dart';
import '../widgets/task_sort_button.dart';
import '../widgets/task_tile.dart';

class QueuePage extends StatefulWidget {
  const QueuePage({super.key});

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  AppState? _app;
  bool _handlingIncoming = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    if (!identical(_app, app)) {
      _app?.removeListener(_onAppChanged);
      _app = app;
      _app!.addListener(_onAppChanged);
      _onAppChanged();
    }
  }

  void _onAppChanged() {
    if (!mounted) return;
    final url = _app?.takeIncomingUrl();
    if (url == null || _handlingIncoming) return;
    _handlingIncoming = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _handlingIncoming = false;
        return;
      }
      await showAddDownloadSheet(context, initialUrl: url);
      _handlingIncoming = false;
      _onAppChanged();
    });
  }

  @override
  void dispose() {
    _app?.removeListener(_onAppChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tasks = app.queueTasks;
    return Scaffold(
      appBar: _buildAppBar(app),
      drawer: const AeroDrawer(),
      body: tasks.isEmpty
          ? EmptyTasks(
              icon: Icons.download_done_rounded,
              title: _emptyTitle(app),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 96),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return TaskTile(
                  task: task,
                  selectionMode: app.selectionMode,
                  selected: app.selectedIds.contains(task.id),
                  onTap: () {
                    if (app.selectionMode) {
                      Haptics.select();
                      app.toggleSelection(task.id);
                    } else {
                      TaskActions.showDetails(context, app, task);
                    }
                  },
                  onLongPress: () {
                    Haptics.medium();
                    app.toggleSelection(task.id);
                  },
                  onToggleSelect: () {
                    Haptics.select();
                    app.toggleSelection(task.id);
                  },
                  onPrimaryAction: () =>
                      TaskActions.primary(context, app, task),
                  onMenuSelected: (action) =>
                      _onMenuAction(context, app, task, action),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Haptics.tap();
          showAddDownloadSheet(context);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建下载'),
      ),
    );
  }

  String _emptyTitle(AppState app) {
    if (app.manager.tasks.isEmpty) return '没有下载任务';
    if (app.completedTaskCount > 0 &&
        app.manager.tasks.length == app.completedTaskCount) {
      return '队列为空';
    }
    return '没有符合条件的任务';
  }

  Future<void> _onMenuAction(
    BuildContext context,
    AppState app,
    DownloadTask task,
    String action,
  ) async {
    switch (action) {
      case 'details':
        await TaskActions.showDetails(context, app, task);
        break;
      case 'open':
        await TaskActions.openFile(context, task);
        break;
      case 'folder':
        await TaskActions.openFolder(context, task);
        break;
      case 'copy':
        await TaskActions.copyUrl(context, task);
        break;
      case 'retry':
        Haptics.tap();
        await app.manager.retry(task);
        break;
      case 'delete':
        await TaskActions.delete(context, app, task);
        break;
    }
  }

  PreferredSizeWidget _buildAppBar(AppState app) {
    if (app.selectionMode) {
      return AppBar(
        leading: IconButton(
          tooltip: '取消选择',
          icon: const Icon(Icons.close_rounded),
          onPressed: app.clearSelection,
        ),
        title: Text('已选择 ${app.selectedIds.length} 项'),
        actions: [
          IconButton(
            tooltip: '全选',
            onPressed: () {
              Haptics.select();
              app.selectAll(app.queueTasks);
            },
            icon: const Icon(Icons.select_all_rounded),
          ),
          IconButton(
            tooltip: '开始',
            onPressed: () {
              Haptics.tap();
              for (final task in app.selectedTasks) {
                if (task.status != TaskStatus.completed) {
                  app.manager.start(task);
                }
              }
              app.clearSelection();
            },
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: '暂停',
            onPressed: () async {
              Haptics.tap();
              for (final task in app.selectedTasks) {
                if (task.status.isActive) await app.manager.pause(task);
              }
              app.clearSelection();
            },
            icon: const Icon(Icons.pause_rounded),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: () =>
                TaskActions.deleteMany(context, app, app.selectedTasks),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      );
    }

    if (_searching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Haptics.select();
            setState(() => _searching = false);
            _searchController.clear();
            app.setSearch('');
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索任务名称或链接',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: app.setSearch,
        ),
        actions: [
          if (app.searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                Haptics.select();
                _searchController.clear();
                app.setSearch('');
              },
            ),
        ],
      );
    }

    return AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          tooltip: '菜单',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {
            Haptics.select();
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('队列'),
          Text(
            '${app.queueTasks.length} 个任务 · ${app.manager.activeCount} 个进行中',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: '搜索',
          onPressed: () {
            Haptics.select();
            setState(() => _searching = true);
          },
          icon: const Icon(Icons.search_rounded),
        ),
        TaskSortButton(app: app),
        PopupMenuButton<String>(
          tooltip: '更多',
          onOpened: Haptics.select,
          onSelected: (value) {
            Haptics.tap();
            if (value == 'start') app.manager.startAll();
            if (value == 'pause') app.manager.pauseAll();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'start', child: Text('全部开始')),
            PopupMenuItem(value: 'pause', child: Text('全部暂停')),
          ],
        ),
      ],
    );
  }
}
