import 'dart:async';
import 'dart:io';
import 'dart:ffi';
import 'dart:isolate';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'offline_engine.dart' show EngineException;
import 'pcm_wave.dart';

class QwenEngine {
  bool _running = false, _cancelled = false;
  SendPort? _commands;

  Future<Map<String, dynamic>> transcribe({
    required String model,
    required String wav,
    required List<Map<String, dynamic>> intervals,
    required int durationMs,
    String language = 'auto',
    String prompt = '',
    void Function(double)? onProgress,
  }) async {
    if (_running) throw StateError('已有转写任务正在运行');
    _running = true;
    _cancelled = false;
    final events = ReceivePort();
    final done = Completer<Map<String, dynamic>>();
    final subscription = events.listen((message) {
      if (done.isCompleted) return;
      if (message == null || message is List) {
        done.completeError(
          const EngineException('Local inference worker exited unexpectedly'),
        );
      } else if (message is Map) {
        switch (message['type']) {
          case 'ready':
            _commands = message['port'] as SendPort;
            if (_cancelled) _commands!.send('cancel');
          case 'progress':
            if (!_cancelled) {
              onProgress?.call((message['value'] as num).toDouble());
            }
          case 'result':
            if (_cancelled) {
              done.completeError(
                const EngineException('cancelled', cancelled: true),
              );
            } else {
              done.complete(Map<String, dynamic>.from(message['value'] as Map));
            }
          case 'error':
            done.completeError(
              EngineException(
                message['message'] as String,
                cancelled: _cancelled || message['cancelled'] == true,
              ),
            );
        }
      }
    });
    try {
      await Isolate.spawn(
        _qwenWorker,
        {
          'events': events.sendPort,
          'model': model,
          'wav': wav,
          'intervals': intervals,
          'durationMs': durationMs,
          'language': language,
          'prompt': prompt,
          'threads': Platform.numberOfProcessors.clamp(1, 4),
          'library': Platform.environment['LINGO_SHERPA_LIBRARY'],
        },
        onError: events.sendPort,
        onExit: events.sendPort,
      );
      return await done.future;
    } finally {
      await subscription.cancel();
      events.close();
      _commands = null;
      _running = false;
    }
  }

  /// Cooperative: a native decode finishes its bounded interval before freeing
  /// native resources. Never kill an isolate in a foreign call or free its model.
  void cancel() {
    _cancelled = true;
    _commands?.send('cancel');
  }
}

Future<void> _qwenWorker(Map<String, dynamic> args) async {
  final events = args['events'] as SendPort;
  final commands = ReceivePort();
  var cancelled = false;
  final subscription = commands.listen((value) {
    if (value == 'cancel') cancelled = true;
  });
  events.send({'type': 'ready', 'port': commands.sendPort});
  sherpa.OfflineRecognizer? recognizer;
  PcmWaveReader? wave;
  late Map<String, dynamic> outcome;
  Future<void> checkpoint() async {
    await Future<void>.delayed(Duration.zero);
    if (cancelled) throw const EngineException('cancelled', cancelled: true);
  }

  try {
    await checkpoint();
    wave = PcmWaveReader.open(args['wav'] as String);
    if ((wave.durationMs - (args['durationMs'] as int)).abs() > 100) {
      throw const FormatException('Normalized WAV duration changed');
    }
    final intervals = (args['intervals'] as List).cast<Map<String, dynamic>>();
    final segments = <Map<String, dynamic>>[];
    if (intervals.isNotEmpty) {
      // The Windows test host may resolve the OS's older ONNX runtime before
      // PATH. Preload the matching package runtime before its C API library.
      if (Platform.isWindows && args['library'] != null) {
        DynamicLibrary.open('${args['library']}/onnxruntime.dll');
      }
      sherpa.initBindings(args['library'] as String?);
      final directory = args['model'] as String;
      recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            tokens: '',
            numThreads: args['threads'] as int,
            debug: false,
            provider: 'cpu',
            qwen3Asr: sherpa.OfflineQwen3AsrModelConfig(
              convFrontend: '$directory/conv_frontend.onnx',
              encoder: '$directory/encoder.int8.onnx',
              decoder: '$directory/decoder.int8.onnx',
              tokenizer: '$directory/tokenizer',
              maxTotalLen: 1024,
              maxNewTokens: 512,
              hotwords: args['prompt'] as String,
            ),
          ),
        ),
      );
      await checkpoint();
      var previousEnd = 0;
      for (final interval in intervals) {
        await checkpoint();
        final start = interval['startMs'] as int,
            end = interval['endMs'] as int;
        if (start < previousEnd) {
          throw const FormatException('Overlapping speech intervals');
        }
        final samples = wave.readRange(start, end);
        final stream = recognizer.createStream();
        String text;
        try {
          final language = args['language'];
          if (language == 'zh' || language == 'en') {
            stream.setOption(
              key: 'language',
              value: language == 'zh' ? 'Chinese' : 'English',
            );
          }
          stream.acceptWaveform(samples: samples, sampleRate: 16000);
          recognizer.decode(stream);
          text = recognizer.getResult(stream).text.trim();
        } finally {
          stream.free();
        }
        await checkpoint();
        if (text.isNotEmpty) {
          segments.add({'startMs': start, 'endMs': end, 'text': text});
        }
        previousEnd = end;
        events.send({'type': 'progress', 'value': end / wave.durationMs});
      }
    }
    await checkpoint();
    outcome = {
      'type': 'result',
      'value': {
        'durationMs': wave.durationMs,
        'segments': segments,
        'timestampSource': 'speech_intervals',
      },
    };
  } catch (error) {
    outcome = {
      'type': 'error',
      'message': error.toString(),
      'cancelled': error is EngineException && error.cancelled,
    };
  } finally {
    wave?.close();
    recognizer?.free();
    await subscription.cancel();
    commands.close();
  }
  events.send(outcome);
}
