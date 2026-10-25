import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../utils/haptics.dart';
import 'browser_page.dart';
import 'completed_page.dart';
import 'queue_page.dart';
import 'settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _PageLoading extends StatelessWidget {
  const _PageLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final List<Widget?> _pages = List<Widget?>.filled(4, null);

  @override
  void initState() {
    super.initState();
    _pages[0] = const QueuePage();
  }

  Widget _pageFor(int index) => switch (index) {
    1 => const CompletedPage(),
    2 => const BrowserPage(),
    3 => const SettingsPage(),
    _ => const QueuePage(),
  };

  void _select(int index) {
    if (index == _index) return;
    Haptics.select();
    context.read<AppState>().clearSelection();
    FocusScope.of(context).unfocus();
    setState(() {
      _index = index;
      if (_pages[index] == null) {
        // Paint the tab switch immediately, then build the (potentially heavy)
        // page on the next frame so the tap never feels frozen.
        _pages[index] = const _PageLoading();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _pages[index] = _pageFor(index);
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < 4; i++) _pages[i] ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download_rounded),
            label: '队列',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.check_circle_rounded),
            label: '已完成',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public_rounded),
            label: '浏览器',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
