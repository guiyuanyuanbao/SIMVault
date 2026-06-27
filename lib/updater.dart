import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n.dart'; // We can use some localized strings if needed, or fallback to Chinese

class UpdateManager {
  static const String _githubRepo = 'guiyuanyuanbao/SIMVault';
  static const String _latestReleaseApi = 'https://api.github.com/repos/$_githubRepo/releases/latest';

  /// Checks for updates and returns a map with details if an update is available, null otherwise.
  static Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      final response = await http.get(Uri.parse(_latestReleaseApi)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final String tagName = data['tag_name'] ?? '';
        final String body = data['body'] ?? '';
        
        // Find APK asset URL
        String apkUrl = data['html_url']; // fallback to release page
        final List assets = data['assets'] ?? [];
        for (var asset in assets) {
          if (asset['name'] != null && asset['name'].toString().endsWith('.apk')) {
            apkUrl = asset['browser_download_url'];
            break;
          }
        }

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version; // e.g. "1.0.0"

        // Strip 'v' prefix if present for comparison
        String latestVersion = tagName;
        if (latestVersion.startsWith('v') || latestVersion.startsWith('V')) {
          latestVersion = latestVersion.substring(1);
        }

        if (_isNewerVersion(currentVersion, latestVersion)) {
          return {
            'version': tagName,
            'notes': body,
            'url': apkUrl,
          };
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
    return null;
  }

  static bool _isNewerVersion(String current, String latest) {
    List<int> currentParts = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    List<int> latestParts = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int c = i < currentParts.length ? currentParts[i] : 0;
      int l = i < latestParts.length ? latestParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static void showUpdateDialog(BuildContext context, Map<String, dynamic> updateInfo, {bool isManualCheck = false}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.system_update_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              const Text('发现新版本', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('最新版本: ${updateInfo['version']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('更新日志:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    updateInfo['notes'],
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('暂不更新', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                final Uri url = Uri.parse(updateInfo['url']);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('无法打开下载链接')),
                  );
                }
              },
              child: const Text('立即下载', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  static Future<void> checkAndUpdate(BuildContext context, {bool showLoading = false, bool isManualCheck = false}) async {
    if (showLoading) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    final updateInfo = await checkForUpdates();

    if (showLoading && context.mounted) {
      Navigator.pop(context);
    }

    if (!context.mounted) return;

    if (updateInfo != null) {
      showUpdateDialog(context, updateInfo, isManualCheck: isManualCheck);
    } else if (isManualCheck) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('当前已经是最新版本 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
