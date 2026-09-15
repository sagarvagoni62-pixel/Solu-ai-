/// Build-time configuration.
///
/// The proxy URL and app key have safe defaults baked in so CI can build
/// without any secrets. Override them per build when needed:
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
  static const String appKey = String.fromEnvironment(
    'SOLU_APP_KEY',
    defaultValue: 'solu_7f3c9a12b45e8d6041af27cc90b3e5d8',
  );

  static bool get isConfigured => proxyBase.isNotEmpty;

  static const String appName = 'Solu AI';
  static const String tagline = 'AI video studio for every Indian family';
  static const String supportEmail = 'support@soluai.app';
  static const String privacyUrl = 'https://soluai.app/privacy';

  /// Max photo edge before upload (keeps uploads fast on 3G).
  static const int maxPhotoEdge = 1280;
}
