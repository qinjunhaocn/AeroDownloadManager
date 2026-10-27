import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../state/app_state.dart';
import 'settings_widgets.dart';
import '../../../utils/constants.dart';
import '../../../utils/haptics.dart';

class ConnectionSettingsPage extends StatelessWidget {
  const ConnectionSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final settings = context.select<AppState, AppSettings>((s) => s.settings);
    return Scaffold(
      appBar: AppBar(title: const Text('连接')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          SettingsSectionCard(
            title: '连接',
            icon: Icons.lan_outlined,
            children: [
              SettingsSliderTile(
                title: '连接超时',
                subtitle: '建立连接与等待响应的最长时间',
                value: settings.timeoutSec.toDouble(),
                min: 5,
                max: 60,
                divisions: 55,
                valueText: '${settings.timeoutSec} 秒',
                onChanged: (value) => state.updateSettings(
                  settings.copyWith(timeoutSec: value.round()),
                ),
              ),
              SettingsSliderTile(
                title: '最大重试次数',
                subtitle: '单条连接失败后的最大尝试次数',
                value: settings.maxRetries.toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                valueText: '${settings.maxRetries}',
                onChanged: (value) => state.updateSettings(
                  settings.copyWith(maxRetries: value.round()),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('代理'),
                subtitle: Text(
                  settings.proxy.isEmpty ? '未设置（仅支持 HTTP 代理）' : settings.proxy,
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => editTextSetting(
                  context,
                  title: 'HTTP 代理',
                  hint: 'host:port',
                  initial: settings.proxy,
                  onSaved: (value) =>
                      state.updateSettings(settings.copyWith(proxy: value)),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('默认 User-Agent'),
                subtitle: Text(
                  settings.userAgent,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => editTextSetting(
                  context,
                  title: 'User-Agent',
                  hint: kDefaultUserAgent,
                  initial: settings.userAgent,
                  maxLines: 3,
                  onSaved: (value) => state.updateSettings(
                    settings.copyWith(
                      userAgent: value.isEmpty ? kDefaultUserAgent : value,
                    ),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.wifiOnly,
                onChanged: (value) {
                  Haptics.select();
                  state.updateSettings(settings.copyWith(wifiOnly: value));
                },
                title: const Text('仅 Wi-Fi 下载'),
                subtitle: const Text('移动网络下自动暂停，连接 Wi-Fi 后继续'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
