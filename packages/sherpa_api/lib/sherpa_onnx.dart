// LingoScribe loader for the Apache-2.0 sherpa-onnx 1.13.8 offline Dart API.
// Android/iOS link our source-built ASR-only backend, with TTS disabled.
import 'dart:ffi';
import 'dart:io';
import 'src/sherpa_onnx_bindings.dart';
export 'src/offline_recognizer.dart';

void initBindings([String? developmentLibraryDirectory]) {
  final DynamicLibrary library;
  if (Platform.isIOS) {
    library = DynamicLibrary.process();
  } else if (Platform.isAndroid) {
    library = DynamicLibrary.open('liboffline_engine.so');
  } else if (developmentLibraryDirectory != null) {
    // Development-host comparison only. These reference libraries are never
    // copied into Android/iOS packages by this package's dependency graph.
    library = DynamicLibrary.open('$developmentLibraryDirectory/${Platform.isWindows ? 'sherpa-onnx-c-api.dll' : 'libsherpa-onnx-c-api.so'}');
  } else {
    throw UnsupportedError('Provide the native development library directory');
  }
  SherpaOnnxBindings.init(library);
}
