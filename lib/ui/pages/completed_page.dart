import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/download_task.dart';
import '../../state/app_state.dart';
import '../../utils/haptics.dart';
import '../widgets/aero_drawer.dart';
import '../widgets/empty_tasks.dart';
import '../widgets/task_actions.dart';
import '../widgets/task_sort_button.dart';
import '../widgets/task_tile.dart';

class CompletedPage extends StatefulWidget {
  const CompletedPage({super.key, this.scaffoldKey});

  final GlobalKey<ScaffoldState>? scaffoldKey;

  @override
  State<CompletedPage> createState() => _CompletedPageState();
}

class _CompletedPageState extends State<CompletedPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tasks = app.completedTasks;
    return Scaffold(
      key: widget.scaffoldKey,
      appBar: _buildAppBar(app),
      drawer: const AeroDrawer(),
      body: AnimatedSwitcher(
        duration: app.settings.animations
            ? const Duration(milliseconds: 220)
            : Duration.zero,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: tasks.isEmpty
            ? EmptyTasks(
                key: ValueKey(
                  'completed-empty-${app.categoryFilter}-${app.searchQuery.isNotEmpty}',
                ),
                icon: Icons.check_circle_outline_rounded,
                title: '还没有已完成的任务',
              )
            : ListView.builder(
                key: ValueKey(
                  'completed-list-${app.categoryFilter}-${app.searchQuery.isNotEmpty}',
                ),
                padding: const EdgeInsets.only(top: 4, bottom: 24),
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
                        TaskActions.primary(context, app, task);
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
                    onMenuSelected: (action) =>
                        _onMenuAction(context, app, task, action),
                  );
                },
              ),
      ),
    );
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
              app.selectAll(app.completedTasks);
            },
            icon: const Icon(Icons.select_all_rounded),
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
            hintText: '搜索已完成任务',
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
          const Text('已完成'),
          Text(
            '${app.completedTasks.length} 个任务',
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
      ],
    );
  }
}
