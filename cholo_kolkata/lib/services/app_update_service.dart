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

  bool shouldPrompt(int installedVersionCode) {
    if (!enabled || updateMode == 'none') return false;
    return installedVersionCode < latestVersionCode;
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
      if (!config.shouldPrompt(installedCode)) return;

      if (!forceCheck && !config.isForce) {
        final prefs = await SharedPreferences.getInstance();
        final dismissedCode = prefs.getInt(_dismissedCodeKey) ?? 0;
        if (dismissedCode >= config.latestVersionCode) {
          return;
        }
      }

      if (!context.mounted) return;
      _isDialogOpen = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: !config.isForce,
        builder: (dialogCtx) => _AppUpdateDialog(
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

class _AppUpdateDialog extends StatefulWidget {
  final AppUpdateConfig config;
  final String installedVersionName;

  const _AppUpdateDialog({
    required this.config,
    required this.installedVersionName,
  });

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
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
        _errorText = 'Could not open Play Store. Please update CholoKolkata from Play Store.';
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
      _statusText = 'Connecting to update server...';
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
            _statusText = 'Downloading update ($recMb$totMb)...';
          });
        }
      }

      await sink.flush();
      await sink.close();

      // Verify downloaded file looks like a valid APK (>1 MB and starts with 'PK')
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
          _statusText = 'Launching Android installer...';
        });
      }

      await _channel.invokeMethod('installApk', {'filePath': outFile.path});
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = 'Tap Install on the system prompt to complete the update.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorText = 'In-app download failed. You can retry or download in browser.';
          _statusText = '';
        });
      }
    } finally {
      client.close();
      _httpClient = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService().currentTheme;
    final isForce = widget.config.isForce;

    return PopScope(
      canPop: !isForce && !_isDownloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isForce ? const Color(0xFFFFEBEE) : theme.lightBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isForce ? 'REQUIRED UPDATE' : 'UPDATE AVAILABLE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: isForce ? const Color(0xFFC62828) : theme.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.config.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'v${widget.installedVersionName} ➔ v${widget.config.latestVersionName}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.primary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.config.releaseNotes.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  widget.config.releaseNotes,
                  style: const TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isDownloading || _statusText.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: theme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _statusText,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                  if (_totalBytes > 0 && _progress != null)
                    Text(
                      '${(_progress! * 100).round()}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: theme.primary),
                    ),
                ],
              ),
              if (_downloadedBytes > 0 && _totalBytes == 0)
                Text(
                  '${(_downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB downloaded',
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
            ],
            if (_errorText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorText,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFC62828)),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          if (!isForce && !_isDownloading)
            TextButton(
              onPressed: _onLaterPressed,
              child: const Text('LATER', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
            ),
          if (!widget.config.isPlayStore && _errorText.isNotEmpty && !_isDownloading)
            TextButton(
              onPressed: () => AppUpdateService().openUpdateUrl(widget.config.downloadUrl),
              child: Text('OPEN IN BROWSER', style: TextStyle(fontWeight: FontWeight.w800, color: theme.primary)),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isForce ? const Color(0xFFD32F2F) : theme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: _isDownloading
                ? null
                : (widget.config.isPlayStore ? _startPlayStoreUpdate : _startDirectApkDownload),
            icon: Icon(
              widget.config.isPlayStore ? Icons.shop_rounded : Icons.system_update_rounded,
              size: 18,
              color: Colors.white,
            ),
            label: Text(
              _isDownloading
                  ? 'DOWNLOADING...'
                  : (widget.config.isPlayStore
                      ? 'UPDATE ON PLAY STORE'
                      : (_errorText.isNotEmpty ? 'RETRY UPDATE' : 'UPDATE NOW')),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
