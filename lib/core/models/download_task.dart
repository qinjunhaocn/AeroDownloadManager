import '../../utils/file_types.dart';

enum TaskKind { http, torrent, magnet }

enum TaskStatus {
  queued,
  connecting,
  downloading,
  waiting,
  paused,
  completed,
  error;

  String get label => switch (this) {
    TaskStatus.queued => '排队中',
    TaskStatus.connecting => '连接中',
    TaskStatus.downloading => '下载中',
    TaskStatus.waiting => '等待中',
    TaskStatus.paused => '已暂停',
    TaskStatus.completed => '已完成',
    TaskStatus.error => '出错',
  };

  bool get isActive =>
      this == TaskStatus.connecting || this == TaskStatus.downloading;

  bool get occupiesSlot =>
      this == TaskStatus.connecting ||
      this == TaskStatus.downloading ||
      this == TaskStatus.waiting;
}

enum SegmentStatus {
  idle,
  running,
  waiting,
  done,
  error;

  String get label => switch (this) {
    SegmentStatus.idle => 'idle',
    SegmentStatus.running => 'running',
    SegmentStatus.waiting => 'waiting',
    SegmentStatus.done => 'done',
    SegmentStatus.error => 'error',
  };
}

class Segment {
  Segment({
    required this.index,
    required this.start,
    required this.pos,
    required this.end,
    this.status = SegmentStatus.idle,
  });

  int index;
  int start;
  int pos;

  /// Exclusive end offset; `-1` means "until EOF".
  int end;
  SegmentStatus status;

  int get downloaded => pos - start;

  int remaining(int total) {
    if (end > 0) return (end - pos).clamp(0, 1 << 62);
    if (total > 0) return (total - pos).clamp(0, 1 << 62);
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'i': index,
    's': start,
    'p': pos,
    'e': end,
    'st': status.index,
  };

  static Segment fromJson(Map<String, dynamic> json) => Segment(
    index: (json['i'] as num?)?.toInt() ?? 0,
    start: (json['s'] as num?)?.toInt() ?? 0,
    pos: (json['p'] as num?)?.toInt() ?? 0,
    end: (json['e'] as num?)?.toInt() ?? -1,
    status:
        SegmentStatus.values[(json['st'] as num?)?.toInt().clamp(0, 4) ?? 0],
  );
}

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.url,
    required this.name,
    required this.directory,
    required this.filePath,
    this.kind = TaskKind.http,
    this.status = TaskStatus.queued,
    this.message = '',
    this.total = 0,
    this.downloaded = 0,
    this.speed = 0,
    this.uploadSpeed = 0,
    this.peers = 0,
    this.seeders = 0,
    this.createdAt = 0,
    this.startedAt,
    this.finishedAt,
    this.userAgent = '',
    this.referer = '',
    this.cookie = '',
    this.authorization = '',
    this.headers = '',
    this.proxy = '',
    this.threads = 0,
    this.speedLimit = 0,
    this.algorithm = -1,
    this.noRange = false,
    this.restartCount = 0,
    this.infoHash = '',
    this.torrentFile = '',
    this.checksum = '',
    this.checksumType = 'md5',
    List<Segment>? segments,
  }) : segments = segments ?? [];

  String id;
  TaskKind kind;

  /// HTTP(S) URL, `magnet:?…`, or a local `.torrent` path.
  String url;
  String name;
  String directory;
  String filePath;
  TaskStatus status;
  String message;

  int total;
  int downloaded;
  double speed;
  double uploadSpeed;
  int peers;
  int seeders;

  int createdAt;
  int? startedAt;
  int? finishedAt;

  String userAgent;
  String referer;
  String cookie;
  String authorization;

  /// Raw request headers, one `Name: value` per line.
  String headers;
  String proxy;

  /// 0 = use global defaults.
  int threads;
  int speedLimit;
  int algorithm;

  bool noRange;
  int restartCount;
  String infoHash;

  /// Cached `.torrent` file for torrent/magnet tasks.
  String torrentFile;

  String checksum;
  String checksumType;

  List<Segment> segments;

  bool get isTorrent => kind != TaskKind.http;
  bool get isFinished => status == TaskStatus.completed;
  bool get isActive => status.isActive;

  DownloadCategory get category => categoryForName(name);

  int get fileType => category.index;

  double get progress {
    if (total > 0) return (downloaded / total).clamp(0.0, 1.0);
    return status == TaskStatus.completed ? 1 : 0;
  }

  int get remaining => total > 0 ? (total - downloaded).clamp(0, total) : 0;

  Duration? get eta => total > 0 && speed > 0
      ? Duration(milliseconds: (remaining / speed * 1000).round())
      : null;

  String get displayName => name.isNotEmpty ? name : url;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.index,
    'url': url,
    'name': name,
    'dir': directory,
    'path': filePath,
    'status': status.index,
    'message': message,
    'total': total,
    'downloaded': downloaded,
    'speed': speed,
    'uploadSpeed': uploadSpeed,
    'peers': peers,
    'seeders': seeders,
    'createdAt': createdAt,
    'startedAt': startedAt,
    'finishedAt': finishedAt,
    'ua': userAgent,
    'referer': referer,
    'cookie': cookie,
    'authorization': authorization,
    'headers': headers,
    'proxy': proxy,
    'threads': threads,
    'speedLimit': speedLimit,
    'algorithm': algorithm,
    'noRange': noRange,
    'restartCount': restartCount,
    'infoHash': infoHash,
    'torrentFile': torrentFile,
    'checksum': checksum,
    'checksumType': checksumType,
    'segments': segments.map((s) => s.toJson()).toList(),
  };

  static DownloadTask fromJson(Map<String, dynamic> json) {
    final kindIndex = (json['kind'] as num?)?.toInt() ?? 0;
    final statusIndex = (json['status'] as num?)?.toInt() ?? 0;
    final segments = <Segment>[];
    final rawSegments = json['segments'];
    if (rawSegments is List) {
      for (final item in rawSegments) {
        if (item is Map) {
          segments.add(Segment.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return DownloadTask(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      kind: TaskKind.values[kindIndex.clamp(0, TaskKind.values.length - 1)],
      url: json['url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      directory: json['dir'] as String? ?? '',
      filePath: json['path'] as String? ?? '',
      status:
          TaskStatus.values[statusIndex.clamp(0, TaskStatus.values.length - 1)],
      message: json['message'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      uploadSpeed: (json['uploadSpeed'] as num?)?.toDouble() ?? 0,
      peers: (json['peers'] as num?)?.toInt() ?? 0,
      seeders: (json['seeders'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      startedAt: (json['startedAt'] as num?)?.toInt(),
      finishedAt: (json['finishedAt'] as num?)?.toInt(),
      userAgent: json['ua'] as String? ?? '',
      referer: json['referer'] as String? ?? '',
      cookie: json['cookie'] as String? ?? '',
      authorization: json['authorization'] as String? ?? '',
      headers: json['headers'] as String? ?? '',
      proxy: json['proxy'] as String? ?? '',
      threads: (json['threads'] as num?)?.toInt() ?? 0,
      speedLimit: (json['speedLimit'] as num?)?.toInt() ?? 0,
      algorithm: (json['algorithm'] as num?)?.toInt() ?? -1,
      noRange: json['noRange'] as bool? ?? false,
      restartCount: (json['restartCount'] as num?)?.toInt() ?? 0,
      infoHash: json['infoHash'] as String? ?? '',
      torrentFile: json['torrentFile'] as String? ?? '',
      checksum: json['checksum'] as String? ?? '',
      checksumType: json['checksumType'] as String? ?? 'md5',
      segments: segments,
    );
  }
}
