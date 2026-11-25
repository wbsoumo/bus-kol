import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'settings_service.dart';

class AppUpdateConfig {
  final bool enabled;
  final String updateMode; // 'none' | 'optional' | 'force'
  final String source; // 'playstore' | 'direct'
  final int latestVersionCode;
  final String latestVersionName;
  final String title;
  final String releaseNotes;
  final String playStoreUrl;
  final String downloadUrl;

  const AppUpdateConfig({
    required this.enabled,
    required this.updateMode,
    required this.source,
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.title,
    required this.releaseNotes,
    required this.playStoreUrl,
    required this.downloadUrl,
  });

  bool get isForce => updateMode == 'force';
  bool get isPlayStore => source == 'playstore';

  factory AppUpdateConfig.fromJson(Map<String, dynamic> json) {
    return AppUpdateConfig(
      enabled: json['enabled'] == true,
      updateMode: (json['update_mode'] ?? 'none').toString().toLowerCase(),
      source: (json['source'] ?? 'direct').toString().toLowerCase(),
      latestVersionCode: (json['latest_version_code'] is num)
          ? (json['latest_version_code'] as num).toInt()
          : (int.tryParse(json['latest_version_code']?.toString() ?? '1') ?? 1),
      latestVersionName: (json['latest_version_name'] ?? '1.0.0').toString(),
      title: (json['title'] ?? 'New CholoKolkata Update Available').toString(),
      releaseNotes: (json['release_notes'] ?? '').toString(),
      playStoreUrl: (json['play_store_url'] ??
              'https://play.google.com/store/apps/details?id=com.cholokolkata.cholo_kolkata')
          .toString(),
      downloadUrl: (json['download_url'] ?? 'http://cholokolkata.online/CholoKolkata.apk').toString(),
    );
  }

  static int _compareVersionNames(String a, String b) {
    final pa = a.split('+').first.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final pb = b.split('+').first.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (int i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  bool shouldPrompt(int installedVersionCode, [String installedVersionName = '1.0.0']) {
    if (!enabled || updateMode == 'none') return false;
    if (installedVersionCode < latestVersionCode) return true;
    if (installedVersionCode == latestVersionCode &&
        _compareVersionNames(installedVersionName, latestVersionName) < 0) {
      return true;
    }
    return false;
  }
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  static const MethodChannel _channel = MethodChannel('com.cholokolkata/app_updater');
  static const String _dismissedCodeKey = 'dismissed_app_update_vcode';

  bool _isChecking = false;
  bool _isDialogOpen = false;

  Future<Map<String, dynamic>> getInstalledAppInfo() async {
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('getAppInfo');
      if (info != null) return info;
    } catch (_) {}
    return {'versionName': '1.0.0', 'versionCode': 1};
  }

  Future<bool> openUpdateUrl(String url, {bool isPlayStore = false}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openUrl', {
        'url': url,
        'isPlayStore': isPlayStore,
      });
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> checkForUpdate(BuildContext context, {bool forceCheck = false}) async {
    if (_isChecking || _isDialogOpen) return;
    _isChecking = true;

    try {
      final appInfo = await getInstalledAppInfo();
      final installedCode = (appInfo['versionCode'] is num)
          ? (appInfo['versionCode'] as num).toInt()
          : 1;
      final installedName = (appInfo['versionName'] ?? '1.0.0').toString();

      final rawCfg = await ApiService().checkAppUpdate();
      if (rawCfg == null) return;

      final config = AppUpdateConfig.fromJson(rawCfg);
      if (!config.shouldPrompt(installedCode, installedName)) return;

      if (!forceCheck && !config.isForce) {
        final prefs = await SharedPreferences.getInstance();
        final dismissedCode = prefs.getInt(_dismissedCodeKey) ?? 0;
        if (dismissedCode >= config.latestVersionCode) {
          return;
        }
      }

      if (!context.mounted) return;
      _isDialogOpen = true;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: !config.isForce,
        enableDrag: !config.isForce,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.62),
        builder: (_) => _AppUpdateSheet(
          config: config,
          installedVersionName: installedName,
        ),
      );
      _isDialogOpen = false;
    } catch (_) {
      _isDialogOpen = false;
    } finally {
      _isChecking = false;
    }
  }
}

class _AppUpdateSheet extends StatefulWidget {
  final AppUpdateConfig config;
  final String installedVersionName;

  const _AppUpdateSheet({
    required this.config,
    required this.installedVersionName,
  });

  @override
  State<_AppUpdateSheet> createState() => _AppUpdateSheetState();
}

class _AppUpdateSheetState extends State<_AppUpdateSheet> {
  static const MethodChannel _channel = MethodChannel('com.cholokolkata/app_updater');

  bool _isDownloading = false;
  double? _progress; // 0.0 - 1.0, null = indeterminate
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String _statusText = '';
  String _errorText = '';
  http.Client? _httpClient;

  @override
  void dispose() {
    _httpClient?.close();
    super.dispose();
  }

  Future<void> _onLaterPressed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppUpdateService._dismissedCodeKey, widget.config.latestVersionCode);
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _startPlayStoreUpdate() async {
    final ok = await AppUpdateService().openUpdateUrl(
      widget.config.playStoreUrl,
      isPlayStore: true,
    );
    if (!ok && mounted) {
      setState(() {
        _errorText = 'Could not open Google Play Store. Please update manually from Play Store.';
      });
    }
  }

  Future<void> _startDirectApkDownload() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _progress = null;
      _downloadedBytes = 0;
      _totalBytes = 0;
      _errorText = '';
      _statusText = 'Connecting to CholoKolkata server...';
    });

    final client = http.Client();
    _httpClient = client;

    try {
      final cacheDir = await _channel.invokeMethod<String>('getCacheDir');
      if (cacheDir == null || cacheDir.isEmpty) {
        throw Exception('Device cache directory unavailable');
      }

      final request = http.Request('GET', Uri.parse(widget.config.downloadUrl));
      final response = await client.send(request).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      final outFile = File('$cacheDir/cholo_update.apk');
      if (await outFile.exists()) {
        await outFile.delete();
      }
      final sink = outFile.openWrite();

      int received = 0;
      List<int>? headerBytes;

      await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
        headerBytes ??= chunk.take(2).toList();
        sink.add(chunk);
        received += chunk.length;
        if (mounted) {
          setState(() {
            _downloadedBytes = received;
            _totalBytes = total;
            _progress = total > 0 ? (received / total).clamp(0.0, 1.0) : null;
            final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
            final totMb = total > 0 ? ' / ${(total / (1024 * 1024)).toStringAsFixed(1)} MB' : ' MB';
            _statusText = 'Downloading package ($recMb$totMb)';
          });
        }
      }

      await sink.flush();
      await sink.close();

      final isZip = headerBytes != null &&
          headerBytes.length >= 2 &&
          headerBytes[0] == 0x50 &&
          headerBytes[1] == 0x4B;
      if (received < 1000000 || !isZip) {
        throw Exception('Downloaded file is not a valid APK package.');
      }

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusText = 'Opening Android package installer...';
        });
      }

      await _channel.invokeMethod('installApk', {'filePath': outFile.path});
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = 'Tap Install on the Android prompt to finish updating.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorText = 'Direct download failed. Tap Retry or Open in Browser.';
          _statusText = '';
        });
      }
    } finally {
      client.close();
      _httpClient = null;
    }
  }

  List<String> _parseHighlights(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];
    final lines = trimmed
        .split(RegExp(r'[\n•]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.length > 1) return lines;
    // Split comma-separated highlights cleanly if single line
    if (trimmed.contains(',')) {
      final parts = trimmed.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2 && parts.length <= 5) {
        return parts.map((p) {
          final clean = p.replaceFirst(RegExp(r'^and\s+', caseSensitive: false), '');
          return clean.isEmpty ? p : '${clean[0].toUpperCase()}${clean.substring(1)}';
        }).toList();
      }
    }
    return [trimmed];
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService().currentTheme;
    final isForce = widget.config.isForce;
    final accent = isForce ? const Color(0xFFD32F2F) : theme.primary;
    final headerGradStart = isForce ? const Color(0xFFB71C1C) : theme.primary;
    final headerGradEnd = isForce ? const Color(0xFFE53935) : theme.secondary;
    final highlights = _parseHighlights(widget.config.releaseNotes);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !isForce && !_isDownloading,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 4 : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gradient Hero Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [headerGradStart, headerGradEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isForce)
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Icon(
                            isForce ? Icons.rocket_launch_rounded : Icons.system_update_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isForce ? 'REQUIRED UPDATE' : 'NEW UPDATE READY',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.config.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Version & Source Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _versionBadge('v${widget.installedVersionName}', muted: true),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 15),
                          ),
                          _versionBadge('v${widget.config.latestVersionName}', muted: false),
                          const Spacer(),
                          Icon(
                            widget.config.isPlayStore ? Icons.shop_rounded : Icons.verified_user_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.config.isPlayStore ? 'Play Store' : 'Official APK',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Body Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (highlights.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 15, color: accent),
                          const SizedBox(width: 6),
                          const Text(
                            "WHAT'S NEW IN THIS VERSION",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF475569),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: highlights.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 15, color: accent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Download Progress Card
                    if (_isDownloading || _statusText.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _statusText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                if (_totalBytes > 0 && _progress != null)
                                  Text(
                                    '${(_progress! * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: accent,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _progress,
                                minHeight: 8,
                                backgroundColor: Colors.white,
                                color: accent,
                              ),
                            ),
                            if (_downloadedBytes > 0 && _totalBytes == 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${(_downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB downloaded',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Error Banner
                    if (_errorText.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Primary Action Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isDownloading
                            ? null
                            : (widget.config.isPlayStore ? _startPlayStoreUpdate : _startDirectApkDownload),
                        icon: Icon(
                          widget.config.isPlayStore ? Icons.shop_rounded : Icons.download_rounded,
                          size: 20,
                        ),
                        label: Text(
                          _isDownloading
                              ? 'DOWNLOADING UPDATE...'
                              : (widget.config.isPlayStore
                                  ? 'UPDATE ON PLAY STORE'
                                  : (_errorText.isNotEmpty ? 'RETRY DOWNLOAD' : 'UPDATE NOW')),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),

                    if (!widget.config.isPlayStore && _errorText.isNotEmpty && !_isDownloading) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            side: BorderSide(color: accent.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => AppUpdateService().openUpdateUrl(widget.config.downloadUrl),
                          icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                          label: const Text(
                            'DOWNLOAD IN BROWSER',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ),
                    ],

                    if (!isForce && !_isDownloading) ...[
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _onLaterPressed,
                        child: const Text(
                          'Remind Me Later',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _versionBadge(String label, {required bool muted}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? Colors.white.withValues(alpha: 0.14) : Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: muted ? Colors.white70 : const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
