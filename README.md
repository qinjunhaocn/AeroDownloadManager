<p align="center">
  <img src="docs/icon.png" width="120" alt="Aero icon" />
</p>

<h1 align="center">Aero Download Manager</h1>

<p align="center">
  <b>多线程下载 · BitTorrent · 内置浏览器</b><br/>
  A Material You download manager for Android, Linux and Windows, inspired by ADM.
</p>

---

## 功能

- **多线程分段下载**：手写 HTTP/1.0 + `Range` 引擎，支持断点续传、探测式大小/文件名识别。
- **两种分段策略**
  - 经典：探测完成后按线程数均分文件；
  - 智能：运行中根据“剩余量 vs 当前段速度”动态对半分裂，连接数逐步增长。
- **断点续传**：每个分段的 `start / pos / end` 持久化到 JSON，重启后按位置继续。
- **限速与队列**：单任务限速、全局同时下载数、每站点并发上限、任务级线程数覆盖。
- **请求控制**：自定义 UA、Referer、Cookie、Authorization、任意请求头、HTTP 代理、校验和（MD5/SHA-1/SHA-256）。
- **BitTorrent**：`.torrent` 文件、远程种子 URL、磁力链接（BEP 9 元数据交换）、DHT、HTTP/UDP 追踪器、PEX/uTP（基于纯 Dart 的 `dtorrent_task`）。
- **内置浏览器**：网页下载拦截、Cookie/Referer 透传、链接一键加入下载（Android / Windows；Linux 使用系统浏览器回退）。
- **Material You**：Android Monet 取色、Windows/Linux 系统强调色、多套种子配色、深浅色主题。
- **系统集成**：Android 前台服务、进度通知、分享链接/打开种子、剪贴板链接提示。

## 平台

| 平台 | 状态 |
|---|---|
| Android 7.0+ | 主目标平台，debug APK 通过 GitHub Actions 构建 |
| Windows 10+ | 支持（WebView2 运行时用于内置浏览器） |
| Linux (GTK3) | 支持（内置浏览器使用系统浏览器回退） |

## 目录结构

```
lib/
  core/
    engine/       下载引擎（worker / 分段 / HTTP / 种子）、任务队列、持久化
    models/       任务、分段、设置
    platform/     原生桥、通知、文件打开
  state/          AppState（筛选、选择、设置、分享入口）
  theme/          Material 3 主题与 Monet 取色
  ui/             页面与组件
  utils/          格式化、类型识别、常量
android/          Kotlin 前台服务 + 分享/打开意图桥
linux/ windows/   桌面 runner
third_party/dart_ipify/  兼容 Dart 3 的 dart_ipify 本地替代（dtorrent_task 依赖）
third_party/flutter_inappwebview_android/  适配 AGP 9 的本地补丁（proguard 文件）
```

## 本地开发

```bash
flutter pub get
flutter analyze
flutter run -d linux        # 或 windows / android
```

> 本项目要求 Flutter `3.47.x`（Dart `3.13.x`）。CI 固定使用 `3.47.8`。

## 构建

```bash
# Android
flutter build apk --debug
flutter build apk --release

# Linux
flutter build linux --release

# Windows
flutter build windows --release
```

Release APK 使用 debug keystore 签名（与 Flutter 模板默认一致），便于直接安装测试。

## CI / 发布流程

| 分支 | 工作流 | 产物 |
|---|---|---|
| `dev` | `.github/workflows/android-debug.yml` | Debug APK + GitHub **Pre-release**（`dev-<run>`） |
| `main` | `.github/workflows/android-release.yml` | Release APK + GitHub Release（`v1.0.<run>`） |

- 日常开发推送到 `dev`，自动构建 debug APK 并创建 prerelease，便于直接下载安装。
- 测试通过后合并到 `main`，自动构建 release 并发布正式 Release。
- 也可以在 Actions 页面手动 `workflow_dispatch` 触发。

## 安全说明

为了与 ADM 的行为保持一致，Aero 默认**接受任意 TLS 证书**（等价于 ADM 的空 `X509TrustManager`），并允许明文 HTTP。这一设计便于下载自签名站点，但会削弱 HTTPS 的中间人防护。请只在你信任的网络中下载敏感内容。

代理目前仅支持 HTTP 代理（Dart `HttpClient` 限制）；SOCKS 未实现。

## 致谢

- 交互与功能灵感来自 **ADM (Advanced Download Manager)**。
- BitTorrent 能力基于 [dtorrent_task](https://pub.dev/packages/dtorrent_task) 及其生态（纯 Dart）。
- UI 使用 Flutter Material 3 与 [dynamic_color](https://pub.dev/packages/dynamic_color)。

## License

MIT © 2026 qinjunhaocn
