import 'package:meta/meta.dart';

/// Native device and application metadata retrieved from the host OS or browser
/// by [OmniNative.getDeviceInfo].
@immutable
class OmniDeviceInfo {
  /// Creates a native device & app info snapshot.
  const OmniDeviceInfo({
    required this.platform,
    this.osVersion = '',
    this.appName = '',
    this.packageName = '',
    this.version = '',
    this.buildNumber = '',
    this.locale = '',
  });

  /// Constructs an [OmniDeviceInfo] from a platform channel result map.
  factory OmniDeviceInfo.fromMap(
    Map<Object?, Object?> map, {
    required String fallbackPlatform,
  }) => OmniDeviceInfo(
    platform: (map['platform'] as String?) ?? fallbackPlatform,
    osVersion: (map['osVersion'] as String?) ?? '',
    appName: (map['appName'] as String?) ?? '',
    packageName: (map['packageName'] as String?) ?? '',
    version: (map['version'] as String?) ?? '',
    buildNumber: (map['buildNumber'] as String?) ?? '',
    locale: (map['locale'] as String?) ?? '',
  );

  /// Target OS/runtime identifier (`android`, `ios`, `macos`, `linux`,
  /// `windows`, or `web`).
  final String platform;

  /// Native OS version or browser user-agent string.
  final String osVersion;

  /// Host application display name.
  final String appName;

  /// Host package / bundle identifier (or host domain on Web).
  final String packageName;

  /// Application semantic version string (e.g. `1.0.0`).
  final String version;

  /// Native build number / version code string (e.g. `1`).
  final String buildNumber;

  /// Active OS/browser locale tag (e.g. `en-US`, `bn-BD`).
  final String locale;

  /// Converts this snapshot into a JSON-compatible map.
  Map<String, String> toMap() => {
    'platform': platform,
    'osVersion': osVersion,
    'appName': appName,
    'packageName': packageName,
    'version': version,
    'buildNumber': buildNumber,
    'locale': locale,
  };

  @override
  String toString() =>
      'OmniDeviceInfo(platform: $platform, osVersion: $osVersion, '
      'appName: $appName, packageName: $packageName, '
      'version: $version+$buildNumber, locale: $locale)';
}
