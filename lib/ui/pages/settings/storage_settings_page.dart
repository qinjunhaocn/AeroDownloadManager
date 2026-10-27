import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../state/app_state.dart';
import 'settings_widgets.dart';

import 'package:file_picker/file_picker.dart';

import '../../../core/engine/download_manager.dart';
import '../../../utils/haptics.dart';

class StorageSettingsPage extends StatelessWidget {
  const StorageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final settings = context.select<AppState, AppSettings>((s) => s.settings);
    return Scaffold(
      appBar: AppBar(title: const Text('存储')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          SettingsSectionCard(
            title: '存储',
            icon: Icons.storage_outlined,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('默认下载目录'),
                subtitle: Text(
                  settings.downloadDir.isEmpty ? '未设置' : settings.downloadDir,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: '选择目录',
                      onPressed: () async {
                        final path = await FilePicker.getDirectoryPath(
                          dialogTitle: '选择默认下载目录',
                        );
                        if (path != null && path.isNotEmpty) {
                          await state.updateSettings(
                            settings.copyWith(downloadDir: path),
                          );
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded),
                    ),
                    IconButton(
                      tooltip: '恢复默认',
                      onPressed: () async {
                        Haptics.select();
                        final path =
                            await DownloadManager.platformDefaultDirectory();
                        await state.updateSettings(
                          settings.copyWith(downloadDir: path),
                        );
                      },
                      icon: const Icon(Icons.restore_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
