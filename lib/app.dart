import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/monet.dart';
import 'ui/pages/main_shell.dart';
import 'utils/constants.dart';

class AeroApp extends StatefulWidget {
  const AeroApp({super.key});

  @override
  State<AeroApp> createState() => _AeroAppState();
}

class _AeroAppState extends State<AeroApp> {
  bool _loadingMonet = false;

  @override
  void initState() {
    super.initState();
    _maybeLoadMonet();
  }

  Future<void> _maybeLoadMonet() async {
    if (_loadingMonet) return;
    _loadingMonet = true;
    await MonetService.ensureLoaded();
    if (mounted) setState(() => _loadingMonet = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    if (settings.monet && !MonetService.hasResult) {
      _maybeLoadMonet();
    }
    final seed = Color(settings.seedColor);
    final light =
        (settings.monet ? MonetService.scheme(Brightness.light) : null) ??
        ColorScheme.fromSeed(seedColor: seed);
    final dark =
        (settings.monet ? MonetService.scheme(Brightness.dark) : null) ??
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildAeroTheme(light, predictiveBack: settings.predictiveBack),
      darkTheme: buildAeroTheme(dark, predictiveBack: settings.predictiveBack),
      themeAnimationDuration: const Duration(milliseconds: 250),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainShell(),
    );
  }
}
