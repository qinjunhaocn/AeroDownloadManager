import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AeroBootstrap());
}

/// Shows a tiny splash while the task database, settings and platform bridges
/// are initialised, then hands control to [AeroApp].
class AeroBootstrap extends StatefulWidget {
  const AeroBootstrap({super.key});

  @override
  State<AeroBootstrap> createState() => _AeroBootstrapState();
}

class _AeroBootstrapState extends State<AeroBootstrap> {
  AppState? _state;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    final state = AppState();
    try {
      await state.init();
      if (!mounted) return;
      setState(() {
        _state = state;
      });
    } catch (error, stack) {
      debugPrint('Aero bootstrap failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAeroTheme(
          ColorScheme.fromSeed(seedColor: const Color(0xFF006A6A)),
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Aero 启动失败',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('$_error', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                      unawaited(_boot());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final state = _state;
    if (state == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAeroTheme(
          ColorScheme.fromSeed(seedColor: const Color(0xFF006A6A)),
        ),
        home: const _Splash(),
      );
    }

    return ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const AeroApp(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(
                Icons.downloading_rounded,
                size: 48,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              kAppName,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            Text(
              kAppTagline,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
