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
    this.description, {
    this.assets = const [],
    this.engine = 'whisper',
    this.repository = 'ggerganov/whisper.cpp',
    this.sourceRevision = revision,
  });
  final String id, name, filename, sha256, description;
  final int bytes;
  final List<ModelAsset> assets;
  final String engine, repository, sourceRevision;
  bool get bundled => assets.isNotEmpty;
  static const revision = '5359861c739e955e79d9a303bcbc70fb988958b1';
  Uri url({bool mirror = false, String? asset}) => Uri.parse(
    'https://${mirror ? 'hf-mirror.com' : 'huggingface.co'}/$repository/resolve/$sourceRevision/${asset ?? filename}',
  );
  String get sizeLabel => '${(bytes / 1000000).toStringAsFixed(0)} MB';
}

class ModelAsset {
  const ModelAsset(this.path, this.bytes, this.sha256);
  final String path, sha256;
  final int bytes;
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
  ModelSpec(
    'qwen3-int8',
    '双语 · Qwen3',
    'qwen3-asr-0.6b-int8',
    987015347,
    '',
    '更强的中文与双语候选模型。约 987 MB 下载，需要较多内存；时间戳按检测到的语音区间生成。',
    engine: 'qwen3',
    repository: 'csukuangfj2/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25',
    sourceRevision: '68818b2313fe77bd06f6a7c5068ff3ef59d02b8a',
    assets: [
      ModelAsset(
        'conv_frontend.onnx',
        44148281,
        'd22dc4423e0940e49884e903d2ea2f7e5567c14fc1aed97e4e26d6b8f208ef9e',
      ),
      ModelAsset(
        'encoder.int8.onnx',
        182491662,
        '60748d3e6744a57c9c91e1b17424a6c2990567e8adceb0783940c03ed98fa9d9',
      ),
      ModelAsset(
        'decoder.int8.onnx',
        755914231,
        '4f6885be5959ae26af3089d38ee7972c5fafbeeb1cf8d5e76eab6d8b61ca5771',
      ),
      ModelAsset(
        'tokenizer/merges.txt',
        1671853,
        '8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5',
      ),
      ModelAsset(
        'tokenizer/tokenizer_config.json',
        12487,
        '4942d005604266809309cabc9f4e9cb89ce855d59b14681fdc0e1cc62ea26c4c',
      ),
      ModelAsset(
        'tokenizer/vocab.json',
        2776833,
        'ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910',
      ),
    ],
  ),
];
Future<String> _digestFile(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();
Future<String> _hashInWorker(String path) =>
    Isolate.run(() => _digestFile(path));

class ModelManager extends ChangeNotifier {
  ModelManager(
    this.directory, {
    http.Client Function()? clientFactory,
    this.catalog = models,
  }) : _clientFactory = clientFactory ?? http.Client.new;
  final Directory directory;
  final List<ModelSpec> catalog;
  final http.Client Function() _clientFactory;
  final Set<String> installed = {};
  String? activeId, downloadingId, error;
  double progress = 0;
  bool verifying = false, _cancelled = false;
  http.Client? _client;
  Future<void> initialize(String? selected) async {
    await directory.create(recursive: true);
    for (final model in catalog) {
      if (model.bundled) {
        final backup = Directory('${pathFor(model)}.previous');
        final target = Directory(pathFor(model));
        if (await backup.exists()) {
          if (!await target.exists()) {
            await backup.rename(target.path);
          } else {
            await backup.delete(recursive: true);
          }
        }
        final partial = Directory('${target.path}.part');
        if (await partial.exists()) await partial.delete(recursive: true);
        if (await _bundlePresent(model, target)) installed.add(model.id);
        continue;
      }
      final partial = File('${pathFor(model)}.part');
      if (await partial.exists()) await partial.delete();
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

  String pathFor(ModelSpec model) {
    if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(model.filename) ||
        model.filename == '..' ||
        model.filename == '.') {
      throw const FormatException('Invalid model filename');
    }
    return p.join(directory.path, model.filename);
  }

  String _assetPath(Directory target, ModelAsset asset) {
    if (p.isAbsolute(asset.path) ||
        asset.path.contains('\\') ||
        asset.path
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw const FormatException('Invalid model asset path');
    }
    return p.join(target.path, asset.path);
  }

  Future<bool> _bundlePresent(ModelSpec model, Directory target) async {
    for (final asset in model.assets) {
      final file = File(_assetPath(target, asset));
      if (!await file.exists() || await file.length() != asset.bytes) {
        return false;
      }
    }
    return true;
  }

  Future<void> _verifyAsset(File file, ModelAsset asset) async {
    if (await file.length() != asset.bytes ||
        await _hashInWorker(file.path) != asset.sha256) {
      throw const FormatException('模型校验失败，请重新下载官方模型');
    }
  }

  ModelSpec? get active => catalog
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
    await verify(model);
  }

  Future<void> verify(ModelSpec model) async {
    if (model.bundled) {
      for (final asset in model.assets) {
        await _verifyAsset(
          File(_assetPath(Directory(pathFor(model)), asset)),
          asset,
        );
      }
    } else {
      await _verify(File(pathFor(model)), model);
    }
  }

  Future<void> download(ModelSpec model, {bool mirror = false}) async {
    if (model.bundled) return _installBundle(model, mirror: mirror);
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

  Future<void> _installBundle(
    ModelSpec model, {
    bool mirror = false,
    Map<String, String>? sources,
  }) async {
    if (downloadingId != null) throw StateError('请等待当前模型操作完成');
    // Validate every name before creating or removing staging directories.
    final target = Directory(pathFor(model));
    final part = Directory('${target.path}.part'),
        backup = Directory('${target.path}.previous');
    if (model.assets.fold<int>(0, (total, asset) => total + asset.bytes) !=
            model.bytes ||
        model.assets.map((asset) => asset.path).toSet().length !=
            model.assets.length) {
      throw const FormatException('Invalid model bundle metadata');
    }
    for (final asset in model.assets) {
      _assetPath(part, asset);
    }
    downloadingId = model.id;
    error = null;
    progress = 0;
    verifying = sources != null;
    _cancelled = false;
    notifyListeners();
    final client = _client = _clientFactory();
    IOSink? sink;
    var committed = false, backedUp = false;
    try {
      if (await part.exists()) await part.delete(recursive: true);
      await part.create(recursive: true);
      var completedBytes = 0;
      final clock = Stopwatch()..start();
      var lastNotified = 0;
      for (final asset in model.assets) {
        if (_cancelled) throw const HttpException('下载已取消');
        final file = File(_assetPath(part, asset));
        await file.parent.create(recursive: true);
        if (sources != null) {
          await File(sources[p.basename(asset.path)]!).copy(file.path);
        } else {
          verifying = false;
          notifyListeners();
          final response = await client
              .send(
                http.Request(
                  'GET',
                  model.url(mirror: mirror, asset: asset.path),
                ),
              )
              .timeout(const Duration(seconds: 30));
          if (response.statusCode != 200) {
            throw HttpException('下载失败（${response.statusCode}）');
          }
          sink = file.openWrite();
          var received = 0;
          await sink.addStream(
            response.stream.timeout(const Duration(seconds: 45)).map((chunk) {
              if (_cancelled) throw const HttpException('下载已取消');
              received += chunk.length;
              if (received > asset.bytes) {
                throw const FormatException('模型文件大小异常');
              }
              progress = (completedBytes + received) / model.bytes;
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
        }
        verifying = true;
        notifyListeners();
        await _verifyAsset(file, asset);
        completedBytes += asset.bytes;
      }
      if (_cancelled) throw const HttpException('下载已取消');
      if (await backup.exists()) {
        throw StateError('Interrupted model replacement requires app restart');
      }
      if (await target.exists()) {
        await target.rename(backup.path);
        backedUp = true;
      }
      try {
        if (_cancelled) throw const HttpException('下载已取消');
        await part.rename(target.path);
        committed = true;
      } catch (_) {
        if (backedUp) await backup.rename(target.path);
        backedUp = false;
        rethrow;
      }
      installed.add(model.id);
      activeId ??= model.id;
      progress = 1;
      if (backedUp) await backup.delete(recursive: true);
    } catch (e) {
      error = _cancelled ? null : e.toString();
      if (sources != null) rethrow;
    } finally {
      try {
        await sink?.close();
      } catch (_) {
        /* Preserve original failure. */
      }
      client.close();
      _client = null;
      try {
        if (!committed && await part.exists()) {
          await part.delete(recursive: true);
        }
      } finally {
        downloadingId = null;
        verifying = false;
        notifyListeners();
      }
    }
  }

  Future<void> importFiles(List<String> paths) async {
    if (paths.length == 1 &&
        p.extension(paths.single).toLowerCase() == '.bin') {
      return importFile(paths.single);
    }
    final sources = {for (final path in paths) p.basename(path): path};
    final model = catalog
        .where(
          (m) =>
              m.bundled &&
              m.assets.length == paths.length &&
              sources.length == paths.length &&
              m.assets.every((a) => sources.containsKey(p.basename(a.path))),
        )
        .firstOrNull;
    if (model == null) {
      throw const FormatException('请选择一个官方模型文件，或完整的 Qwen3 六个文件');
    }
    await _installBundle(model, sources: sources);
  }

  Future<void> importFile(String source) async {
    if (downloadingId != null) throw StateError('请等待当前模型操作完成');
    final file = File(source);
    final size = await file.length();
    final model = catalog
        .where((m) => !m.bundled && m.bytes == size)
        .firstOrNull;
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
    if (model.bundled) {
      final folder = Directory(pathFor(model));
      if (await folder.exists()) await folder.delete(recursive: true);
    } else {
      final file = File(pathFor(model));
      if (await file.exists()) await file.delete();
    }
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
