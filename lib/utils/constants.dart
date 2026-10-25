import 'package:flutter/material.dart';

const String kAppName = 'Aero';
const String kAppTagline = 'Download Manager';
const String kPackageName = 'com.voxyn.aero';
const String kRepoUrl = 'https://github.com/qinjunhaocn/AeroDownloadManager';
const String kAppVersion = '1.0.0';
const int kAppBuild = 1;

/// Matches the mobile Chrome UA used by ADM by default. Users can override it
/// per download or globally in Settings.
const String kDefaultUserAgent =
    'Mozilla/5.0 (Linux; Android 14; SM-S911B Build/UP1A.231005.007; wv) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
    'Chrome/124.0.6367.82 Mobile Safari/537.36';

const int kChunkSize = 64 * 1024;
const int kProbeBytes = 256;
const int kPreallocateThreshold = 10 * 1024 * 1024;
const int kMinSegmentBytes = 256 * 1024;

/// Seed palettes offered in Settings when Monet is disabled.
const List<({String name, Color color})> kSeedColors = [
  (name: 'Aero Teal', color: Color(0xFF006A6A)),
  (name: 'Ocean', color: Color(0xFF00639B)),
  (name: 'Indigo', color: Color(0xFF4A5C92)),
  (name: 'Violet', color: Color(0xFF6B4E9B)),
  (name: 'Forest', color: Color(0xFF3B6B3B)),
  (name: 'Amber', color: Color(0xFF8B5E00)),
  (name: 'Rose', color: Color(0xFF8E4A5B)),
  (name: 'Graphite', color: Color(0xFF4A4A4A)),
];
