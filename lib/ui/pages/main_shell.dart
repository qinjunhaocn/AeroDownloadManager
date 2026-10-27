import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_settings.dart';
import '../../state/app_state.dart';
import '../../utils/haptics.dart';
import '../widgets/glass_surface.dart';
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

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  final List<Widget?> _pages = List<Widget?>.filled(4, null);
  final GlobalKey<ScaffoldState> _queueKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ScaffoldState> _completedKey = GlobalKey<ScaffoldState>();
  AppState? _app;
  late final AnimationController _tabFade;

  @override
  void initState() {
    super.initState();
    _tabFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
    _pages[0] = QueuePage(scaffoldKey: _queueKey);
    // Preload the browser tab so its configured home page is ready before the
    // user switches to it.
    _pages[2] = const BrowserPage(active: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    if (!identical(_app, app)) {
      _app?.removeListener(_onAppStateChanged);
      _app = app;
      app.addListener(_onAppStateChanged);
    }
  }

  void _onAppStateChanged() {
    final app = _app;
    if (app == null || !mounted) return;
    final tab = app.pendingTab;
    if (tab == null) return;
    app.consumePendingTab();
    _select(tab, clearSelection: false);
  }

  @override
  void dispose() {
    _app?.removeListener(_onAppStateChanged);
    _tabFade.dispose();
    super.dispose();
  }

  void _closeDrawers() {
    _queueKey.currentState?.closeDrawer();
    _completedKey.currentState?.closeDrawer();
  }

  Widget _pageFor(int index) => switch (index) {
    1 => CompletedPage(scaffoldKey: _completedKey),
    2 => BrowserPage(active: _index == 2),
    3 => const SettingsPage(),
    _ => QueuePage(scaffoldKey: _queueKey),
  };

  void _select(int index, {bool clearSelection = true}) {
    if (index == _index) {
      _closeDrawers();
      return;
    }
    Haptics.select();
    _closeDrawers();
    final animations = context.read<AppState>().settings.animations;
    if (animations) {
      _tabFade.forward(from: 0);
    } else {
      _tabFade.value = 1;
    }
    if (clearSelection) {
      context.read<AppState>().clearSelection();
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _index = index;
      if (_pages[2] != null && _pages[2] is BrowserPage) {
        _pages[2] = BrowserPage(active: index == 2);
      }
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
    context.select<AppState, AppSettings>((state) => state.settings);
    return Scaffold(
      body: FadeTransition(
        opacity: _tabFade,
        child: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < 4; i++) _pages[i] ?? const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: GlassSurface(
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
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
      ),
    );
  }
}
