import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../api/solu_api.dart';
import '../data/scenes.dart';
import 'history_store.dart';

enum GenStage { idle, uploading, queued, rendering, saving, done, error }

/// Drives the whole photo -> video flow and exposes progress for the UI.
class GenerationController extends ChangeNotifier {
  GenerationController({SoluApi? api}) : _api = api ?? SoluApi();
  final SoluApi _api;

  GenStage stage = GenStage.idle;
  double progress = 0;
  String label = '';
  String? errorMessage;
  File? videoFile;
  String? remoteUrl;
  String? _jobId;
  bool _cancelled = false;

  bool get isBusy =>
      stage != GenStage.idle && stage != GenStage.done && stage != GenStage.error;

  Future<void> start({
    required Scene scene,
    required File photo,
    File? photo2,
  }) async {
    _cancelled = false;
    errorMessage = null;
    videoFile = null;
    _set(GenStage.uploading, 0.06, 'Photo upload ho rahi hai');

    try {
      final url1 = await _api.uploadPhoto(photo);
      if (_cancelled) return;

      String? url2;
      if (scene.needsTwoPhotos) {
        if (photo2 == null) {
          throw SoluException('second_photo_required', 'missing second photo');
        }
        _set(GenStage.uploading, 0.1, 'Doosri photo upload ho rahi hai');
        url2 = await _api.uploadPhoto(photo2);
      }
      if (_cancelled) return;

      _set(GenStage.queued, 0.14, 'Chehra lock ho gaya');

      final result = await _api.generate(
        sceneId: scene.id,
        imageUrl: url1,
        imageUrl2: url2,
        onJob: (id) => _jobId = id,
        onProgress: (p) {
          if (_cancelled) return;
          _set(GenStage.rendering, p, _renderLabel(p, scene));
        },
        timeout: Duration(minutes: scene.seconds >= 10 ? 10 : 8),
      );
      if (_cancelled) return;

      final asset = result.first;
      if (result.state != JobState.completed || asset == null) {
        throw SoluException('failed', 'no asset returned');
      }

      _set(GenStage.saving, 0.96, 'Video save ho rahi hai');
      final file = await _download(asset.url);
      remoteUrl = asset.url;
      videoFile = file;

      await HistoryStore.add(HistoryItem(
        id: const Uuid().v4(),
        sceneId: scene.id,
        title: scene.title,
        filePath: file.path,
        remoteUrl: asset.url,
        createdAt: DateTime.now(),
      ));

      _set(GenStage.done, 1, 'Ready');
    } on SoluException catch (e) {
      debugPrint('generation failed: $e');
      errorMessage = e.userMessage;
      _set(GenStage.error, progress, 'Error');
    } catch (e) {
      debugPrint('generation crashed: $e');
      errorMessage = SoluException('unknown', '$e').userMessage;
      _set(GenStage.error, progress, 'Error');
    }
  }

  Future<void> cancel() async {
    _cancelled = true;
    final id = _jobId;
    if (id != null) await _api.cancel(id);
    _set(GenStage.idle, 0, '');
  }

  String _renderLabel(double p, Scene scene) {
    if (p < 0.3) return 'Scene taiyar ho raha hai';
    if (p < 0.55) return 'Divine light add ho rahi hai';
    if (p < 0.8) return 'Motion render ho raha hai';
    return 'Final touches';
  }

  void _set(GenStage s, double p, String l) {
    stage = s;
    progress = p;
    label = l;
    notifyListeners();
  }

  /// Provider URLs expire - copy to app storage immediately.
  Future<File> _download(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw SoluException('network', 'download failed ${res.statusCode}');
    }
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/solu_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final file = File(path);
    await file.writeAsBytes(res.bodyBytes);
    return file;
  }
}
