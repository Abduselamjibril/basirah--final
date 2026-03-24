import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';

class VersioningService {
  static const String appId = 'com.basirahtv.app';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=$appId&hl=en&gl=ET';

  static Future<String?> getLatestVersion() async {
    print('DEBUG: [VersioningService] Fetching version from Play Store...');
    try {
      final response = await http
          .get(Uri.parse(playStoreUrl))
          .timeout(const Duration(seconds: 10));
      
      print('DEBUG: [VersioningService] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final body = response.body;
        print('DEBUG: [VersioningService] Body length: ${body.length}');
        
        // Try multiple regex patterns as Play Store often updates their structure
        final patterns = [
           r'\["(\d+\.\d+\.\d+)"\]', // Common in modern Play Store JSON
           r'"(\d+\.\d+\.\d+)"',     // General quoted version string
           r'SoftwareVersion[^\d]+(\d+\.\d+\.\d+)', // Older metadata format
        ];

        for (final pattern in patterns) {
          final regex = RegExp(pattern);
          final matches = regex.allMatches(body);
          
          for (final match in matches) {
            final version = match.group(1);
            if (version != null && _isValidVersion(version)) {
              print('DEBUG: [VersioningService] Found version: $version using pattern: $pattern');
              return version;
            }
          }
        }
        print('DEBUG: [VersioningService] No version pattern matched in body');
      }
    } catch (e) {
      print('DEBUG: [VersioningService] Error: $e');
    }
    return null;
  }

  static bool _isValidVersion(String version) {
    final parts = version.split('.');
    if (parts.length < 2) return false;
    // For this specific app, we know versions are likely around 1.1.x
    if (version.startsWith('1.1.') || version.startsWith('1.2.')) return true;
    return false;
  }
}

/// A custom store for Upgrader that uses our manual scraper.
class ManualUpgraderStore extends UpgraderStore {
  @override
  Future<UpgraderVersionInfo> getVersionInfo({
    required UpgraderState state,
    required Version installedVersion,
    required String? country,
    required String? language,
  }) async {
    if (state.debugLogging) {
      print('upgrader: ManualUpgraderStore.getVersionInfo called');
    }

    final latestVersionStr = await VersioningService.getLatestVersion();
    Version? appStoreVersion;
    if (latestVersionStr != null) {
      try {
        appStoreVersion = Version.parse(latestVersionStr);
        if (state.debugLogging) {
          print('upgrader: ManualUpgraderStore found version: $appStoreVersion');
        }
      } catch (e) {
        if (state.debugLogging) {
          print('upgrader: ManualUpgraderStore error parsing version: $e');
        }
      }
    }

    return UpgraderVersionInfo(
      installedVersion: installedVersion,
      appStoreListingURL: 'https://play.google.com/store/apps/details?id=${VersioningService.appId}',
      appStoreVersion: appStoreVersion,
      isCriticalUpdate: false,
    );
  }
}
