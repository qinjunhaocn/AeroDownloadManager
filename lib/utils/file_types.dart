import 'dart:io';

import 'package:flutter/material.dart';

enum DownloadCategory {
  archive,
  program,
  video,
  audio,
  image,
  document,
  other;

  String get label => switch (this) {
    DownloadCategory.archive => '压缩包',
    DownloadCategory.program => '程序',
    DownloadCategory.video => '视频',
    DownloadCategory.audio => '音频',
    DownloadCategory.image => '图片',
    DownloadCategory.document => '文档',
    DownloadCategory.other => '其他',
  };

  IconData get icon => switch (this) {
    DownloadCategory.archive => Icons.folder_zip_outlined,
    DownloadCategory.program => Icons.terminal_rounded,
    DownloadCategory.video => Icons.movie_outlined,
    DownloadCategory.audio => Icons.music_note_rounded,
    DownloadCategory.image => Icons.image_outlined,
    DownloadCategory.document => Icons.description_outlined,
    DownloadCategory.other => Icons.insert_drive_file_outlined,
  };

  Color get color => switch (this) {
    DownloadCategory.archive => const Color(0xFF9C6B3F),
    DownloadCategory.program => const Color(0xFFE07A1F),
    DownloadCategory.video => const Color(0xFFD1465B),
    DownloadCategory.audio => const Color(0xFF7C5CBF),
    DownloadCategory.image => const Color(0xFF2E8B57),
    DownloadCategory.document => const Color(0xFF3B75B5),
    DownloadCategory.other => const Color(0xFF6B7280),
  };
}

const Map<DownloadCategory, Set<String>> _extensions = {
  DownloadCategory.archive: {
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
    'bz2',
    'xz',
    'zst',
    'iso',
    'cab',
    'arj',
    'lzh',
    'lz',
    'tgz',
    'tbz',
    'txz',
    'zipx',
    'jar',
    'war',
    'apks',
    'xapk',
    'obb',
    'img',
    'dmg',
    'wim',
    'gho',
    '001',
    '002',
    '003',
    'r01',
    'r02',
  },
  DownloadCategory.program: {
    'apk',
    'exe',
    'msi',
    'msix',
    'appx',
    'deb',
    'rpm',
    'pkg',
    'dmg',
    'appimage',
    'flatpak',
    'snap',
    'ipa',
    'sis',
    'sisx',
    'sh',
    'bat',
    'cmd',
    'ps1',
    'py',
    'pyc',
    'lua',
    'lnk',
    'dll',
    'so',
    'dylib',
    'bin',
    'run',
    'x86_64',
    'aab',
  },
  DownloadCategory.video: {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'm4v',
    'mpg',
    'mpeg',
    'ts',
    'm2ts',
    'mts',
    '3gp',
    '3g2',
    'ogv',
    'rmvb',
    'rm',
    'vob',
    'divx',
    'asf',
    'f4v',
    'm3u8',
    'mpd',
    'qt',
    'mxf',
  },
  DownloadCategory.audio: {
    'mp3',
    'flac',
    'aac',
    'ac3',
    'm4a',
    'm4b',
    'ogg',
    'oga',
    'opus',
    'wav',
    'wma',
    'aiff',
    'aif',
    'alac',
    'ape',
    'amr',
    'mid',
    'midi',
    'mka',
    'dsf',
    'dff',
    'tta',
    'wv',
    'm3u',
    'pls',
  },
  DownloadCategory.image: {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg',
    'svgz',
    'tif',
    'tiff',
    'heic',
    'heif',
    'avif',
    'ico',
    'psd',
    'ai',
    'raw',
    'cr2',
    'nef',
    'dng',
    'jxl',
    'apng',
  },
  DownloadCategory.document: {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'odt',
    'ods',
    'odp',
    'txt',
    'md',
    'rtf',
    'epub',
    'mobi',
    'azw',
    'azw3',
    'fb2',
    'djvu',
    'chm',
    'csv',
    'tsv',
    'json',
    'xml',
    'yaml',
    'yml',
    'html',
    'htm',
    'css',
    'js',
    'log',
    'nfo',
    'srt',
    'ass',
    'vtt',
    'tex',
    'bib',
    'ics',
    'vcf',
    'torrent',
  },
};

DownloadCategory categoryForName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return DownloadCategory.other;
  final ext = name.substring(dot + 1).toLowerCase();
  for (final entry in _extensions.entries) {
    if (entry.value.contains(ext)) return entry.key;
  }
  return DownloadCategory.other;
}

/// Best-effort file name from a URL's path or query.
String fileNameFromUrl(Uri uri, {String fallback = 'download'}) {
  String? candidate;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty) candidate = segments.last;
  for (final key in const [
    'filename',
    'file',
    'name',
    'fn',
    'title',
    'download',
  ]) {
    final value = uri.queryParameters[key];
    if (value != null && value.trim().isNotEmpty) {
      candidate = value.trim();
      break;
    }
  }
  if (candidate == null || candidate.isEmpty) return fallback;
  try {
    return sanitizeFileName(Uri.decodeComponent(candidate));
  } catch (_) {
    return sanitizeFileName(candidate);
  }
}

String sanitizeFileName(String name) {
  var result = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (result.isEmpty) result = 'download';
  if (result.length > 180) {
    final dot = result.lastIndexOf('.');
    if (dot > 0 && result.length - dot < 12) {
      result =
          result.substring(0, 180 - (result.length - dot)) +
          result.substring(dot);
    } else {
      result = result.substring(0, 180);
    }
  }
  return result;
}

String uniqueFileName(String directory, String name) {
  final separator = directory.endsWith('/') ? '' : '/';
  var candidate = '$directory$separator$name';
  if (!File(candidate).existsSync()) return name;
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  final stamp = DateTime.now()
      .toIso8601String()
      .substring(0, 19)
      .replaceAll(':', '-')
      .replaceAll('T', '_');
  candidate = '$directory$separator${base}_$stamp$ext';
  var index = 1;
  while (File(candidate).existsSync()) {
    candidate = '$directory$separator${base}_${stamp}_$index$ext';
    index++;
  }
  return candidate.substring(candidate.lastIndexOf('/') + 1);
}
