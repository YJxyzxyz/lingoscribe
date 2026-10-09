import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

typedef _CreateNative =
    Pointer<Void> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int32,
    );
typedef _Create =
    Pointer<Void> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
    );
typedef _IntNative = Int32 Function(Pointer<Void>);
typedef _Int = int Function(Pointer<Void>);
typedef _VoidNative = Void Function(Pointer<Void>);
typedef _Void = void Function(Pointer<Void>);
typedef _ResultNative = Pointer<Utf8> Function(Pointer<Void>);
typedef _Result = Pointer<Utf8> Function(Pointer<Void>);

class _Bindings {
  _Bindings() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('liboffline_engine.so')
        : Platform.isIOS
        ? DynamicLibrary.process()
        : DynamicLibrary.open(
            Platform.environment['LINGO_ENGINE_LIBRARY'] ??
                'offline_engine.dll',
          );
    create = lib.lookupFunction<_CreateNative, _Create>('ls_job_create_v2');
    run = lib.lookupFunction<_IntNative, _Int>('ls_job_run');
    progress = lib.lookupFunction<_IntNative, _Int>('ls_job_progress');
    phase = lib.lookupFunction<_IntNative, _Int>('ls_job_phase');
    cancel = lib.lookupFunction<_VoidNative, _Void>('ls_job_cancel');
    result = lib.lookupFunction<_ResultNative, _Result>('ls_job_result');
    free = lib.lookupFunction<_VoidNative, _Void>('ls_job_free');
  }
  late final _Create create;
  late final _Int run, progress, phase;
  late final _Void cancel, free;
  late final _Result result;
}

int _runNative(int address) =>
    _Bindings().run(Pointer<Void>.fromAddress(address));
Future<int> _dispatchNative(int address) =>
    Isolate.run(() => _runNative(address));

class OfflineEngine {
  static const _channel = MethodChannel('lingoscribe/offline_engine');
  _Bindings? _bindings;
  Pointer<Void>? _job;

  Future<int> normalize(String source, String destination) async {
    final value = await _channel.invokeMethod<int>('normalize', {
      'source': source,
      'destination': destination,
    });
    if (value == null || value <= 0) throw StateError('音频中没有可读取的声音');
    return value;
  }

  Future<void> protectDirectory(String path) async {
    await _channel.invokeMethod<void>('protectDirectory', {'path': path});
  }

  Future<Map<String, dynamic>> transcribe({
    required String model,
    required String wav,
    String language = 'auto',
    String prompt = '',
    String vad = '',
    void Function(double)? onProgress,
    void Function(int)? onPhase,
  }) async {
    if (_job != null) throw StateError('已有转写任务正在运行');
    final bindings = _bindings ??= _Bindings();
    final strings = [
      model,
      wav,
      language,
      prompt,
      vad,
    ].map((s) => s.toNativeUtf8()).toList();
    late Pointer<Void> job;
    try {
      job = bindings.create(
        strings[0],
        strings[1],
        strings[2],
        strings[3],
        strings[4],
        Platform.numberOfProcessors.clamp(1, 4),
      );
    } finally {
      for (final value in strings) {
        calloc.free(value);
      }
    }
    if (job == nullptr) throw StateError('无法分配转写任务');
    _job = job;
    final address = job.address;
    final timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      onProgress?.call(bindings.progress(job) / 100);
      onPhase?.call(bindings.phase(job));
    });
    try {
      // Static function avoids capturing unsendable native bindings in this isolate.
      final code = await _dispatchNative(address);
      final result =
          jsonDecode(bindings.result(job).toDartString())
              as Map<String, dynamic>;
      if (code != 0) {
        throw EngineException(
          result['error'] as String? ?? '转写失败',
          cancelled: code == 1,
        );
      }
      onProgress?.call(1);
      return result;
    } finally {
      timer.cancel();
      _job = null;
      bindings.free(job);
    }
  }

  void cancel() {
    final job = _job;
    if (job != null) _bindings!.cancel(job);
  }
}

class EngineException implements Exception {
  const EngineException(this.message, {this.cancelled = false});
  final String message;
  final bool cancelled;
  @override
  String toString() => message;
}
