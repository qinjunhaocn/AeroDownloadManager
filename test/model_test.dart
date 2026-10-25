import 'package:flutter_test/flutter_test.dart';

import 'package:aero_download_manager/core/models/download_task.dart';
import 'package:aero_download_manager/utils/file_types.dart';
import 'package:aero_download_manager/utils/formatters.dart';

void main() {
  test('task json round trip keeps segments and options', () {
    final task = DownloadTask(
      id: '1',
      url: 'https://example.com/file.zip',
      name: 'file.zip',
      directory: '/tmp',
      filePath: '/tmp/file.zip',
      total: 1000,
      downloaded: 250,
      threads: 8,
      speedLimit: 1024,
      algorithm: 1,
      segments: [
        Segment(index: 0, start: 0, pos: 250, end: 500),
        Segment(index: 1, start: 500, pos: 500, end: -1),
      ],
    );
    final restored = DownloadTask.fromJson(task.toJson());
    expect(restored.name, 'file.zip');
    expect(restored.threads, 8);
    expect(restored.segments.length, 2);
    expect(restored.segments.first.pos, 250);
    expect(restored.segments.last.end, -1);
  });

  test('formatters are stable', () {
    expect(formatBytes(1024), '1.0 KB');
    expect(formatPercent(0.5), '50%');
    expect(formatDuration(65000), '1m 05s');
  });

  test('file type detection', () {
    expect(categoryForName('movie.mkv'), DownloadCategory.video);
    expect(categoryForName('song.flac'), DownloadCategory.audio);
    expect(categoryForName('archive.7z'), DownloadCategory.archive);
    expect(categoryForName('no-extension'), DownloadCategory.other);
    expect(fileNameFromUrl(Uri.parse('https://a/b/c.mp4?x=1')), 'c.mp4');
  });
}
