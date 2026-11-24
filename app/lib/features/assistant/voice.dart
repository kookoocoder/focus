import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Phonon 31m (English, Apache 2.0) from Hugging Face, downloaded once into
/// app storage. About 64 MB.
abstract final class PhononModel {
  static const _repo = 'https://huggingface.co/gradium/phonon-31m-en/resolve/main';
  static const _files = ['config.json', 'tokenizer.json', 'default-voice.safetensors', 'model.q8.gguf'];
  static const _ch = MethodChannel('focus/tts');

  static Future<String> dir() async =>
      '${(await getApplicationSupportDirectory()).path}/phonon-31m-en';

  static Future<bool> ready() async {
    try {
      return await _ch.invokeMethod<bool>('ready', {'dir': await dir()}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the missing files. [onProgress] gets 0..1.
  static Future<void> download(void Function(double) onProgress) async {
    final d = Directory(await dir())..createSync(recursive: true);
    final client = http.Client();
    try {
      for (final (i, f) in _files.indexed) {
        final out = File('${d.path}/$f');
        if (out.existsSync()) continue;
        final res = await client.send(http.Request('GET', Uri.parse('$_repo/$f')));
        if (res.statusCode != 200) throw HttpException('$f: HTTP ${res.statusCode}');
        final total = res.contentLength ?? 0;
        final tmp = File('${out.path}.part');
        final sink = tmp.openWrite();
        var got = 0;
        await for (final chunk in res.stream) {
          sink.add(chunk);
          got += chunk.length;
          final part = total == 0 ? 0 : got / total;
          // The weights are nearly all of the bytes.
          onProgress(f == 'model.q8.gguf' ? .05 + .95 * part : .05 * (i + part) / 3);
        }
        await sink.close();
        await tmp.rename(out.path);
      }
      onProgress(1);
    } finally {
      client.close();
    }
  }

  static Future<void> delete() async {
    final d = Directory(await dir());
    if (d.existsSync()) await d.delete(recursive: true);
  }
}

/// Speaks assistant replies. [onPos] reports how many characters have been
/// spoken, so the text can roll out with the voice; [onDone] fires at the end.
class VoiceOut {
  VoiceOut({required this.onPos, required this.onDone});
  final void Function(int pos) onPos;
  final void Function() onDone;

  static const _ch = MethodChannel('focus/tts');
  static const _events = EventChannel('focus/tts/events');
  final _system = FlutterTts();
  StreamSubscription? _sub;
  int? _id;
  bool _usingSystem = false;

  Future<void> init() async {
    _sub = _events.receiveBroadcastStream().listen((e) {
      final m = (e as Map).cast<String, dynamic>();
      if (m['id'] != _id) return;
      if (m['pos'] != null) onPos(m['pos'] as int);
      if (m['done'] == true || m['error'] != null) {
        _id = null;
        onDone();
      }
    });
    _system.setProgressHandler((_, _, end, _) {
      if (_usingSystem) onPos(end);
    });
    _system.setCompletionHandler(() {
      if (!_usingSystem) return;
      _usingSystem = false;
      onDone();
    });
    if (await PhononModel.ready()) {
      await _ch.invokeMethod('warm', {'dir': await PhononModel.dir()});
    }
  }

  Future<void> speak(String text) async {
    await stop();
    if (await PhononModel.ready()) {
      _id = await _ch.invokeMethod<int>('speak', {'dir': await PhononModel.dir(), 'text': text});
      return;
    }
    _usingSystem = true;
    await _system.speak(text);
  }

  Future<void> stop() async {
    _id = null;
    _usingSystem = false;
    await _ch.invokeMethod('stop');
    await _system.stop();
  }

  void dispose() {
    stop();
    _sub?.cancel();
  }
}
