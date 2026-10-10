import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class ModelSpec {
  const ModelSpec(
    this.id,
    this.name,
    this.filename,
    this.bytes,
    this.sha256,
    this.description,
  );
  final String id, name, filename, sha256, description;
  final int bytes;
  static const revision = '5359861c739e955e79d9a303bcbc70fb988958b1';
  Uri url({bool mirror = false}) => Uri.parse(
    'https://${mirror ? 'hf-mirror.com' : 'huggingface.co'}/ggerganov/whisper.cpp/resolve/$revision/$filename',
  );
  String get sizeLabel => '${(bytes / 1000000).toStringAsFixed(0)} MB';
}

const models = [
  ModelSpec(
    'base-q5',
    '轻量 · Base',
    'ggml-base-q5_1.bin',
    59707625,
    '422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898',
    '较小下载体积，适合短笔记。多语言，Q5 量化。',
  ),
  ModelSpec(
    'small-q5',
    '精细 · Small',
    'ggml-small-q5_1.bin',
    190085487,
    'ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb',
    '更大的多语言模型，适合访谈与双语录音。速度与内存取决于设备。',
  ),
];
Future<String> _digestFile(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();
Future<String> _hashInWorker(String path) =>
    Isolate.run(() => _digestFile(path));

class ModelManager extends ChangeNotifier {
  ModelManager(this.directory, {http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;
  final Directory directory;
  final http.Client Function() _clientFactory;
  final Set<String> installed = {};
  String? activeId, downloadingId, error;
  double progress = 0;
  bool verifying = false, _cancelled = false;
  http.Client? _client;
  Future<void> initialize(String? selected) async {
    await directory.create(recursive: true);
    for (final model in models) {
      final file = File(pathFor(model));
      if (await file.exists() && await file.length() == model.bytes) {
        installed.add(model.id);
      }
    }
    activeId = installed.contains(selected)
        ? selected
        : installed.isEmpty
        ? null
        : installed.first;
    notifyListeners();
  }

  String pathFor(ModelSpec model) => p.join(directory.path, model.filename);
  ModelSpec? get active => models
      .where((m) => m.id == activeId && installed.contains(m.id))
      .firstOrNull;
  void select(String id) {
    if (installed.contains(id)) {
      activeId = id;
      notifyListeners();
    }
  }

  Future<void> _verify(File file, ModelSpec model) async {
    if (await file.length() != model.bytes ||
        await _hashInWorker(file.path) != model.sha256) {
      throw const FormatException('模型校验失败，请重新下载官方模型');
    }
  }

  Future<void> verifyActive() async {
    final model = active;
    if (model == null) throw StateError('请先下载或导入一个模型');
    await _verify(File(pathFor(model)), model);
  }

  Future<void> download(ModelSpec model, {bool mirror = false}) async {
    if (downloadingId != null) return;
    downloadingId = model.id;
    error = null;
    progress = 0;
    _cancelled = false;
    notifyListeners();
    final part = File('${pathFor(model)}.part');
    final client = _client = _clientFactory();
    IOSink? sink;
    try {
      final response = await client
          .send(http.Request('GET', model.url(mirror: mirror)))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('下载失败（${response.statusCode}）');
      }
      sink = part.openWrite();
      var received = 0;
      final clock = Stopwatch()..start();
      var lastNotified = 0;
      // addStream applies disk backpressure, avoiding unbounded queued model bytes.
      await sink.addStream(
        response.stream.timeout(const Duration(seconds: 45)).map((chunk) {
          if (_cancelled) throw const HttpException('下载已取消');
          received += chunk.length;
          if (received > model.bytes) throw const FormatException('模型文件大小异常');
          progress = received / model.bytes;
          if (clock.elapsedMilliseconds - lastNotified >= 100) {
            lastNotified = clock.elapsedMilliseconds;
            notifyListeners();
          }
          return chunk;
        }),
      );
      await sink.flush();
      await sink.close();
      sink = null;
      verifying = true;
      notifyListeners();
      await _verify(part, model);
      if (_cancelled) throw const HttpException('下载已取消');
      await part.rename(pathFor(model));
      installed.add(model.id);
      activeId ??= model.id;
    } catch (e) {
      error = _cancelled ? null : e.toString();
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (e) {
          if (!_cancelled) error ??= e.toString();
        }
      }
      client.close();
      _client = null;
      try {
        if (await part.exists()) await part.delete();
      } catch (e) {
        error ??= e.toString();
      }
      downloadingId = null;
      verifying = false;
      notifyListeners();
    }
  }

  void cancelDownload() {
    _cancelled = true;
    _client?.close();
  }

  Future<void> importFile(String source) async {
    if (downloadingId != null) throw StateError('请等待当前模型操作完成');
    final file = File(source);
    final size = await file.length();
    final model = models.where((m) => m.bytes == size).firstOrNull;
    if (model == null) {
      throw const FormatException('只支持目录中列出的官方 Base / Small Q5 模型');
    }
    downloadingId = model.id;
    verifying = true;
    error = null;
    notifyListeners();
    final part = File('${pathFor(model)}.part');
    try {
      await file.copy(part.path);
      await _verify(part, model);
      await part.rename(pathFor(model));
      installed.add(model.id);
      activeId ??= model.id;
    } finally {
      try {
        if (await part.exists()) await part.delete();
      } finally {
        downloadingId = null;
        verifying = false;
        notifyListeners();
      }
    }
  }

  Future<void> remove(ModelSpec model) async {
    if (downloadingId != null) throw StateError('请等待当前模型操作完成');
    final file = File(pathFor(model));
    if (await file.exists()) await file.delete();
    installed.remove(model.id);
    if (activeId == model.id) activeId = installed.firstOrNull;
    notifyListeners();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}
