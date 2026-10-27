import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../state/app_state.dart';
import 'settings_widgets.dart';
import '../../../utils/search_engines.dart';

class BrowserSettingsPage extends StatelessWidget {
  const BrowserSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final settings = context.select<AppState, AppSettings>((s) => s.settings);
    return Scaffold(
      appBar: AppBar(title: const Text('浏览器')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          SettingsSectionCard(
            title: '浏览器',
            icon: Icons.public_rounded,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('默认主页'),
                subtitle: Text(
                  settings.browserHome.isEmpty
                      ? 'https://www.bing.com'
                      : settings.browserHome,
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => editTextSetting(
                  context,
                  title: '浏览器默认主页',
                  hint: 'https://www.bing.com',
                  initial: settings.browserHome,
                  onSaved: (value) {
                    final normalized = value.trim().isEmpty
                        ? 'https://www.bing.com'
                        : normalizeUrlInput(value);
                    state.updateSettings(
                      settings.copyWith(browserHome: normalized),
                    );
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('搜索引擎'),
                subtitle: Text(SearchEngines.nameOf(settings.searchEngine)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => chooseSearchEngine(context, state, settings),
              ),
              Text(
                '默认主页在应用启动时预加载；搜索引擎用于地址栏中非网址内容的搜索。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
