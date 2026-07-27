import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

// Same failover domain list as main.dart — the version-check endpoint is
// tried on each in turn so a single blocked/down domain doesn't prevent
// the update check from ever completing.
const _versionCheckDomains = ['go-now.uk', 'come100.com', 'manxiaomao.com'];

Future<Map<String, dynamic>?> _fetchLatestVersion() async {
  for (final d in _versionCheckDomains) {
    try {
      final resp = await http
          .get(Uri.parse('https://manga.$d/api/app_version.php'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {
      // try next domain
    }
  }
  return null;
}

/// Checks for a new version and, if found, shows an update dialog.
/// When [silent] is true, does nothing (no dialog, no toast) if already
/// up to date or if the check itself fails — used for the automatic
/// background check on app launch, so it never bothers the user unless
/// there's actually something to show.
Future<void> checkForUpdate(BuildContext context, {required bool silent}) async {
  final info = await _fetchLatestVersion();
  final packageInfo = await PackageInfo.fromPlatform();
  final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;

  if (info == null) {
    if (!silent && context.mounted) {
      _showSnack(context, '检查更新失败，请检查网络后重试');
    }
    return;
  }

  final latestCode = (info['version_code'] as num?)?.toInt() ?? 0;
  if (latestCode <= currentCode) {
    if (!silent && context.mounted) {
      _showSnack(context, '已是最新版本 (v${packageInfo.version})');
    }
    return;
  }

  if (!context.mounted) return;
  final versionName = info['version_name'] as String? ?? '';
  final notes = info['notes'] as String? ?? '';
  final force = info['force'] == true;
  final downloadUrl = info['download_url'] as String? ?? '';

  await showDialog(
    context: context,
    barrierDismissible: !force,
    builder: (dialogCtx) => PopScope(
      canPop: !force,
      child: AlertDialog(
        title: Text(force ? '⚠️ 需要更新才能继续使用' : '🎉 发现新版本 v$versionName'),
        content: Text(
          notes.isNotEmpty
              ? notes
              : (force
                  ? '此版本包含重要更新，请更新后继续使用。'
                  : '有新版本可用，建议更新以获得最佳体验。'),
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('稍后'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              if (downloadUrl.isNotEmpty) {
                _downloadAndInstall(context, downloadUrl, force: force);
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    ),
  );
}

void _showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );
}

Future<void> _downloadAndInstall(
  BuildContext context,
  String url, {
  required bool force,
}) async {
  final progress = ValueNotifier<double>(0);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('正在下载更新…'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value > 0 ? value : null),
              const SizedBox(height: 12),
              Text(value > 0 ? '${(value * 100).toStringAsFixed(0)}%' : '连接中…'),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final filePath = '${dir.path}/MangaXiaomao_update.apk';
    final file = File(filePath);
    if (await file.exists()) await file.delete();

    final req = http.Request('GET', Uri.parse(url));
    final resp = await req.send();
    final total = resp.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    await for (final chunk in resp.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) progress.value = received / total;
    }
    await sink.close();

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    await OpenFilex.open(filePath);
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _showSnack(context, '下载失败，请稍后重试或前往浏览器下载');
    }
  }
}
