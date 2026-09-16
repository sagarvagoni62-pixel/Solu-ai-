import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import '../data/scenes.dart';

enum JobState { queued, running, completed, failed, expired }

class SoluAsset {
  final String type;
  final String url;
  const SoluAsset(this.type, this.url);
  factory SoluAsset.fromJson(Map<String, dynamic> j) =>
      SoluAsset((j['type'] as String?) ?? 'video', (j['url'] as String?) ?? '');
}

class SoluJob {
  final String id;
  final String sceneId;
  final int seconds;
  const SoluJob({required this.id, required this.sceneId, required this.seconds});
}

class SoluResult {
  final JobState state;
  final List<SoluAsset> assets;
  final String? error;
  const SoluResult(this.state, [this.assets = const [], this.error]);
  SoluAsset? get first => assets.isEmpty ? null : assets.first;
}

class SoluException implements Exception {
  final String code;
  final String message;
  SoluException(this.code, this.message);

  @override
  String toString() => 'SoluException($code): $message';

  /// Ready-to-show Hinglish copy. Unknown codes are shown as-is so a single
  /// screenshot is enough to debug the backend.
  String get userMessage {
    switch (code) {
      case 'not_configured':
        return 'App server se connect nahi hai. Thodi der baad try karein.';
      case 'unauthorized':
      case 'http_401':
        return 'Server ne app key reject ki (401). Backend key update karni hai.';
      case 'no_storage':
        return 'Server storage set nahi hai (KV). Backend fix chahiye.';
      case 'photo_required':
        return 'Pehle photo choose karein.';
      case 'second_photo_required':
        return 'Is scene ke liye 2 photo chahiye.';
      case 'too_large':
        return 'Photo bahut badi hai. Chhoti photo choose karein.';
      case 'face_not_clear':
        return 'Chehra saaf nahi hai. Doosri photo try karein.';
      case 'moderation':
        return 'Ye photo allowed nahi hai. Doosri photo try karein.';
      case 'rate_limited':
        return 'Bahut requests. 1 minute baad try karein.';
      case 'insufficient_credits':
        return 'API key ka credit khatam hai. Naye credits daalein.';
      case 'upload_failed':
        return 'Photo upload nahi hui. Internet check karein.';
      case 'upstream_error':
        return 'Video service ne request reject ki.\n\n$message';
      case 'network':
        return 'Internet connection check karein.';
      case 'timeout':
        return 'Zyada waqt lag raha hai. My Videos me baad me check karein.';
      default:
        return 'Kuch galat ho gaya.\n\ncode: $code\n$message';
    }
  }
}

/// Talks to the Solu Worker, which runs the hidden character-sheet step and
/// then the reference-to-video step on BlitzReels with one API key. The app
/// only ever sees one job id and the final video.
class SoluApi {
  SoluApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static String? _deviceId;

  static Future<String> deviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('solu_device_id');
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString('solu_device_id', id);
    }
    _deviceId = id;
    return id;
  }

  Uri _u(String path) => Uri.parse('${SoluConfig.proxyBase}$path');

  Future<Map<String, String>> _headers() async => {
        'content-type': 'application/json',
        'x-solu-key': SoluConfig.appKey,
        'x-solu-device': await deviceId(),
      };

  void _requireConfig() {
    if (!SoluConfig.isConfigured) {
      throw SoluException('not_configured', 'proxy base is empty');
    }
  }

  // ----------------------------------------------------------- diagnostics

  /// Public health endpoint, no app key needed.
  Future<Map<String, dynamic>> health() async {
    final r = await _http
        .get(_u('/v1/health'))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw SoluException('http_${r.statusCode}', r.body);
    }
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  /// One-tap check of every link in the chain. Rendered as plain text so it
  /// can be screenshotted and acted on directly.
  Future<String> selfTest() async {
    final out = <String>['proxy: ${SoluConfig.proxyBase}'];

    Map<String, dynamic> h;
    try {
      h = await health();
    } catch (e) {
      out.add('server: FAIL - $e');
      return out.join('\n');
    }
    out.add('server: OK (${h['provider']})');
    out.add('api key: ${h['apiKey'] ?? 'MISSING'}');
    out.add('configured: ${h['configured']}');
    out.add('storage: ${h['storage']}');
    out.add('image model: ${h['imageModel']}');
    out.add('video model: ${h['videoModel']}');

    // /v1/upstream needs the app key AND a working BlitzReels key, so it tests
    // both hops at once.
    try {
      final up = await _get('/v1/upstream?path=/generation-options');
      final raw = jsonEncode(up['data']);
      out.add('app key: OK');
      out.add(
          'upstream: OK ${raw.substring(0, raw.length > 400 ? 400 : raw.length)}');
    } on SoluException catch (e) {
      if (e.code == 'unauthorized' || e.code == 'http_401') {
        out.add('app key: FAIL - ${e.code}');
      } else {
        out.add('app key: OK');
        out.add('upstream: FAIL - ${e.code}: ${e.message}');
      }
    } catch (e) {
      out.add('upstream: FAIL - $e');
    }

    return out.join('\n');
  }

  // ---------------------------------------------------------------- scenes

  /// Remote catalogue; falls back to the bundled list when offline.
  Future<List<Scene>> scenes() async {
    if (!SoluConfig.isConfigured) return SceneCatalog.all;
    try {
      final res = await _get('/v1/scenes');
      final list = (res['scenes'] as List?) ?? const [];
      if (list.isEmpty) return SceneCatalog.all;
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final local = SceneCatalog.byId(m['id'] as String);
        m['poster'] = SceneCatalog.posterFor(m['id'] as String);
        m['subtitle'] ??= local?.subtitle;
        m['category'] ??= local?.category;
        m['featured'] ??= local?.featured;
        return Scene.fromJson(m);
      }).toList(growable: false);
    } catch (_) {
      return SceneCatalog.all; // never block the UI on catalogue fetch
    }
  }

  // ---------------------------------------------------------------- upload

  /// Uploads a local photo into the generation backend and returns the asset
  /// reference used by both generation stages.
  Future<String> uploadPhoto(File file) async {
    _requireConfig();
    try {
      final req = http.MultipartRequest('POST', _u('/v1/upload'))
        ..headers['x-solu-key'] = SoluConfig.appKey
        ..headers['x-solu-device'] = await deviceId()
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await req.send().timeout(const Duration(seconds: 120));
      final res = await http.Response.fromStream(streamed);
      final body = _decode(res);
      final ref = (body['assetId'] as String?) ?? (body['url'] as String?);
      if (ref == null || ref.isEmpty) {
        throw SoluException('upload_failed', 'no asset in response');
      }
      return ref;
    } on SoluException {
      rethrow;
    } on TimeoutException {
      throw SoluException('timeout', 'upload timed out');
    } catch (e) {
      throw SoluException('upload_failed', e.toString());
    }
  }

  // ------------------------------------------------------------- generate

  /// [imageUrl] is the value returned by [uploadPhoto].
  Future<SoluJob> submit({
    required String sceneId,
    required String imageUrl,
    String? imageUrl2,
  }) async {
    _requireConfig();
    final res = await _post('/v1/generate', {
      'sceneId': sceneId,
      'assetId': imageUrl,
      if (imageUrl2 != null && imageUrl2.isNotEmpty) 'assetId2': imageUrl2,
    });
    return SoluJob(
      id: (res['id'] as String?) ?? (res['jobId'] as String),
      sceneId: (res['sceneId'] as String?) ?? sceneId,
      seconds: (res['seconds'] as num?)?.toInt() ?? 10,
    );
  }

  Future<JobState> status(String jobId) async {
    final res = await _get('/v1/jobs/$jobId/status');
    return _parse((res['state'] as String?) ?? (res['status'] as String?));
  }

  Future<SoluResult> result(String jobId) async {
    final res = await _get('/v1/jobs/$jobId');
    final assets = <SoluAsset>[];
    final videoUrl = res['videoUrl'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      assets.add(SoluAsset('video', videoUrl));
    }
    for (final e in (res['assets'] as List?) ?? const []) {
      final a = SoluAsset.fromJson(Map<String, dynamic>.from(e as Map));
      if (a.url.isNotEmpty) assets.add(a);
    }
    return SoluResult(
      _parse((res['state'] as String?) ?? (res['status'] as String?)),
      assets,
      res['error'] as String?,
    );
  }

  Future<void> cancel(String jobId) async {
    try {
      await _http.put(_u('/v1/jobs/$jobId/cancel'), headers: await _headers());
    } catch (_) {/* best effort */}
  }

  /// Submit then poll with backoff until the video is ready.
  Future<SoluResult> generate({
    required String sceneId,
    required String imageUrl,
    String? imageUrl2,
    void Function(double progress)? onProgress,
    void Function(String jobId)? onJob,
    Duration timeout = const Duration(minutes: 12),
  }) async {
    final job = await submit(
        sceneId: sceneId, imageUrl: imageUrl, imageUrl2: imageUrl2);
    onJob?.call(job.id);

    final deadline = DateTime.now().add(timeout);
    var delay = const Duration(seconds: 3);
    var progress = 0.12;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(delay);
      final next = delay.inSeconds + 1;
      delay = Duration(seconds: next > 10 ? 10 : next);

      final res = await result(job.id);
      if (res.state == JobState.completed) {
        onProgress?.call(0.95);
        return res;
      }
      if (res.state == JobState.failed || res.state == JobState.expired) {
        if (res.error != null && res.error!.isNotEmpty) {
          throw SoluException('upstream_error', res.error!);
        }
        return res;
      }
      progress += 0.045;
      if (progress > 0.9) progress = 0.9;
      onProgress?.call(progress);
    }
    throw SoluException('timeout', 'generation timed out');
  }

  // ----------------------------------------------------------------- http

  JobState _parse(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'DONE':
      case 'COMPLETED':
        return JobState.completed;
      case 'ERROR':
      case 'FAILED':
        return JobState.failed;
      case 'EXPIRED':
      case 'CANCELED':
      case 'CANCELLED':
        return JobState.expired;
      case 'QUEUED':
      case 'IN_QUEUE':
        return JobState.queued;
      default:
        return JobState.running;
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> b) async {
    try {
      final r = await _http
          .post(_u(path), headers: await _headers(), body: jsonEncode(b))
          .timeout(const Duration(seconds: 60));
      return _decode(r);
    } on SoluException {
      rethrow;
    } on TimeoutException {
      throw SoluException('timeout', 'request timed out');
    } catch (e) {
      throw SoluException('network', e.toString());
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final r = await _http
          .get(_u(path), headers: await _headers())
          .timeout(const Duration(seconds: 60));
      return _decode(r);
    } on SoluException {
      rethrow;
    } on TimeoutException {
      throw SoluException('timeout', 'request timed out');
    } catch (e) {
      throw SoluException('network', e.toString());
    }
  }

  Map<String, dynamic> _decode(http.Response r) {
    Map<String, dynamic> body = <String, dynamic>{};
    if (r.body.isNotEmpty) {
      try {
        body = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      } catch (_) {
        body = <String, dynamic>{};
      }
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return body;

    final err = body['error'] as Map?;
    var code = err?['code'] as String?;
    code ??= r.statusCode == 402
        ? 'insufficient_credits'
        : r.statusCode == 429
            ? 'rate_limited'
            : r.statusCode == 401
                ? 'unauthorized'
                : 'http_${r.statusCode}';
    final fallback = r.body.isEmpty
        ? 'request failed'
        : r.body.substring(0, r.body.length > 300 ? 300 : r.body.length);
    throw SoluException(code, (err?['message'] as String?) ?? fallback);
  }
}
