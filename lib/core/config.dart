/// Build-time configuration.
///
/// Nothing secret lives in this file, so the repository can be public. The
/// app key is injected by CI from the SOLU_APP_KEY / APP_SHARED_SECRET
/// repository secret:
///
/// flutter build apk --release \
///   --dart-define=SOLU_PROXY=https://solu-ai-proxy.xxx.workers.dev \
///   --dart-define=SOLU_APP_KEY=<APP_SHARED_SECRET>
///
/// No provider API key ever lives in the app. Everything goes through the proxy.
class SoluConfig {
  static const String proxyBase = String.fromEnvironment(
    'SOLU_PROXY',
    defaultValue: 'https://solu-ai-proxy.sagarvagoni62.workers.dev',
  );

  /// Empty by default on purpose: a build without the key simply cannot talk
  /// to the backend, instead of shipping a working key to everyone.
  static const String appKey = String.fromEnvironment('SOLU_APP_KEY');

  static bool get isConfigured => proxyBase.isNotEmpty && appKey.isNotEmpty;

  static const String appName = 'Solu AI';
  static const String tagline = 'AI video studio for every Indian family';
  static const String supportEmail = 'support@soluai.app';
  static const String privacyUrl = 'https://soluai.app/privacy';

  /// Max photo edge before upload (keeps uploads fast on 3G).
  static const int maxPhotoEdge = 1280;
}
