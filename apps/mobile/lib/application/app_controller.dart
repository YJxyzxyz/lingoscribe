import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:offline_engine/offline_engine.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/transcript_repository.dart';
import '../domain/transcript.dart';
import '../services/model_manager.dart';
import '../services/recording_recovery.dart';
import '../services/bundled_detector.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.repository,
    required this.root,
    required this.models,
    required this.preferences,
    OfflineEngine? engine,
    AudioRecorder? recorder,
  }) : engine = engine ?? OfflineEngine(),
       recorder = recorder ?? AudioRecorder();
  final TranscriptRepository repository;
  final Directory root;
  final ModelManager models;
  final SharedPreferences preferences;
  final OfflineEngine engine;
  final AudioRecorder recorder;
  List<TranscriptSummary> items = [];
  int dataRevision = 0;
  String query = '', language = 'auto', prompt = '';
  String? taskId, error, phase;
  double progress = 0, amplitude = -60;
  Transcript? recording;
  Transcript? autoSavedRecording;
  String? recordingLimitError;
  bool paused = false, importing = false;
  int recordingMs = 0;
  final Stopwatch _watch = Stopwatch();
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitude;
  bool get busy => taskId != null || recording != null || importing;
  bool get onboarded => preferences.getBool('onboarded') ?? false;

  static Future<AppController> create() async {
    final root = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'lingoscribe'),
    );
    await root.create(recursive: true);
    final engine = OfflineEngine();
    await engine.protectDirectory(root.path);
    final preferences = await SharedPreferences.getInstance();
    final modelManager = ModelManager(Directory(p.join(root.path, 'models')));
    await modelManager.initialize(preferences.getString('model'));
    final repository = await TranscriptRepository.open(
      p.join(root.path, 'library.sqlite'),
    );
    for (final interrupted in await repository.interruptedRecordings()) {
      if (interrupted.status == TranscriptStatus.interrupted &&
          interrupted.source == 'recording' &&
          interrupted.audioPath ==
              p.join(root.path, 'audio', '${interrupted.id}.wav')) {
        final duration = await recoverRecording(File(interrupted.audioPath));
        if (duration != null) {
          await repository.save(
            interrupted.copyWith(
              durationMs: duration,
              error: '任务被中断，音频已恢复或确认可读取，可重试转写。',
            ),
          );
        }
      }
    }
    final controller = AppController(
      repository: repository,
      root: root,
      models: modelManager,
      preferences: preferences,
      engine: engine,
    );
    controller.language = preferences.getString('language') ?? 'auto';
    controller.prompt = preferences.getString('prompt') ?? '';
    modelManager.addListener(controller._onModelsChanged);
    await controller.refresh();
    return controller;
  }

  void _onModelsChanged() {
    final selected = models.activeId ?? '';
    if (preferences.getString('model') != selected) {
      unawaited(preferences.setString('model', selected));
    }
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    await preferences.setBool('onboarded', true);
    notifyListeners();
  }

  Future<void> settings({String? language, String? prompt}) async {
    this.language = language ?? this.language;
    this.prompt = prompt ?? this.prompt;
    await preferences.setString('language', this.language);
    await preferences.setString('prompt', this.prompt);
    notifyListeners();
  }

  int _refreshSerial = 0;
  Future<void> refresh({String? query}) async {
    if (query != null) this.query = query;
    final serial = ++_refreshSerial;
    final result = await repository.summaries(query: this.query);
    if (serial != _refreshSerial) return;
    items = result;
    notifyListeners();
  }

  Future<void> save(Transcript value) async {
    await repository.save(value);
    dataRevision++;
    await refresh();
  }

  Future<Transcript?> find(String id) => repository.get(id);
  Future<void> remove(Transcript value) async {
    if (value.id == taskId || value.id == recording?.id) {
      throw StateError('请先结束当前任务');
    }
    final audio = File(value.audioPath);
    if (await audio.exists()) await audio.delete();
    final wav = File(p.join(root.path, 'audio', '${value.id}.normalized.wav'));
    if (await wav.exists()) await wav.delete();
    await repository.delete(value.id);
    dataRevision++;
    await refresh();
  }

  Future<void> startRecording() async {
    if (busy) throw StateError('请先结束当前任务');
    if (!await recorder.hasPermission()) {
      throw StateError('需要麦克风权限才能录音，请在系统设置中允许。');
    }
    final id = const Uuid().v4();
    final folder = Directory(p.join(root.path, 'audio'));
    await folder.create(recursive: true);
    final now = DateTime.now();
    final value = Transcript(
      id: id,
      title:
          '录音 ${now.month}/${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      createdAt: now,
      audioPath: p.join(folder.path, '$id.wav'),
      status: TranscriptStatus.recording,
      language: language,
      prompt: prompt,
    );
    await repository.save(value);
    try {
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
        path: value.audioPath,
      );
      recording = value;
      autoSavedRecording = null;
      recordingLimitError = null;
      paused = false;
      recordingMs = 0;
      _watch
        ..reset()
        ..start();
      _amplitude = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((value) {
            amplitude = value.current;
            notifyListeners();
          });
      _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        recordingMs = _watch.elapsedMilliseconds;
        notifyListeners();
        if (recordingMs >= 7200000) {
          _timer?.cancel();
          unawaited(
            stopRecording()
                .then<void>((saved) {
                  if (saved != null) {
                    autoSavedRecording = saved;
                    notifyListeners();
                  }
                })
                .catchError((Object failure) {
                  recordingLimitError = '录音已停止，保存记录失败。请重启应用以恢复本地音频。';
                  notifyListeners();
                }),
          );
        }
      });
      notifyListeners();
    } catch (e) {
      await repository.delete(id);
      rethrow;
    }
  }

  bool _changingPause = false;
  Future<void> togglePause() async {
    if (recording == null || _changingPause) return;
    _changingPause = true;
    final next = !paused;
    try {
      if (next) {
        await recorder.pause();
        _watch.stop();
      } else {
        await recorder.resume();
        _watch.start();
      }
      paused = next;
    } finally {
      _changingPause = false;
      notifyListeners();
    }
  }

  bool _stopping = false;
  Future<Transcript?> stopRecording({bool discard = false}) async {
    final value = recording;
    if (value == null || _stopping) return null;
    _stopping = true;
    try {
      final path = await recorder.stop();
      _watch.stop();
      _timer?.cancel();
      await _amplitude?.cancel();
      recording = null;
      paused = false;
      if (discard) {
        await remove(value);
        return null;
      }
      final recovered = await recoverRecording(File(value.audioPath));
      final saved = value.copyWith(
        status: path != null
            ? TranscriptStatus.saved
            : recovered != null
            ? TranscriptStatus.interrupted
            : TranscriptStatus.failed,
        durationMs: recovered ?? _watch.elapsedMilliseconds,
        error: path == null
            ? recovered != null
                  ? '录音中断，已恢复本地音频，可继续转写。'
                  : '录音未正常结束。请检查麦克风权限后重新录音。'
            : null,
      );
      await save(saved);
      return saved;
    } finally {
      _stopping = false;
      notifyListeners();
    }
  }

  Future<Transcript?> importAudio() async {
    if (busy) throw StateError('请先结束当前任务');
    importing = true;
    phase = '正在导入音频';
    notifyListeners();
    String? copiedPath;
    try {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'wav',
          'mp3',
          'm4a',
          'aac',
          'flac',
          'ogg',
          'mp4',
          'mov',
        ],
        withData: false,
      );
      if (selected == null || selected.files.single.path == null) return null;
      final input = File(selected.files.single.path!);
      if (await input.length() > 2 * 1024 * 1024 * 1024) {
        throw StateError('文件超过 2 GB，请先裁剪音频');
      }
      final id = const Uuid().v4();
      final folder = Directory(p.join(root.path, 'audio'));
      await folder.create(recursive: true);
      final path = p.join(
        folder.path,
        '$id${p.extension(input.path).toLowerCase()}',
      );
      copiedPath = path;
      await input.copy(path);
      final normalized = p.join(folder.path, '$id.normalized.wav');
      final duration = await engine.normalize(path, normalized);
      final value = Transcript(
        id: id,
        title: p.basenameWithoutExtension(selected.files.single.name),
        createdAt: DateTime.now(),
        audioPath: path,
        durationMs: duration,
        source: 'import',
        language: language,
        prompt: prompt,
      );
      await save(value);
      copiedPath = null;
      return value;
    } finally {
      if (copiedPath != null) {
        final copied = File(copiedPath);
        if (await copied.exists()) await copied.delete();
        final normalized = File(
          p.join(
            p.dirname(copiedPath),
            '${p.basenameWithoutExtension(copiedPath)}.normalized.wav',
          ),
        );
        if (await normalized.exists()) await normalized.delete();
      }
      importing = false;
      phase = null;
      notifyListeners();
    }
  }

  Future<void> transcribe(Transcript value) async {
    if (busy) throw StateError('请先结束当前任务');
    if (value.segments.isNotEmpty) {
      throw StateError('请先复制或导出已有校对文本，重转写功能暂不覆盖已有内容');
    }
    final model = models.active;
    if (model == null) throw StateError('请在模型管理中下载或导入模型，然后离线转写');
    taskId = value.id;
    progress = 0;
    error = null;
    phase = '正在验证本地模型';
    notifyListeners();
    var working = value.copyWith(
      status: TranscriptStatus.transcribing,
      modelId: model.id,
      clearError: true,
    );
    try {
      await save(working);
      await models.verifyActive();
      final detector = await prepareSpeechDetector(root);
      phase = '正在准备音频';
      notifyListeners();
      final normalized = p.join(
        root.path,
        'audio',
        '${value.id}.normalized.wav',
      );
      final duration = await engine.normalize(value.audioPath, normalized);
      working = working.copyWith(durationMs: duration);
      await repository.save(working);
      dataRevision++;
      phase = '正在设备上转写';
      notifyListeners();
      final result = await engine.transcribe(
        model: models.pathFor(model),
        wav: normalized,
        language: value.language,
        prompt: value.prompt,
        vad: detector,
        onPhase: (state) {
          phase = switch (state) {
            0 => '正在载入本地模型',
            2 => '正在检查可能遗漏的语音',
            4 => '正在检测语音区间',
            _ => '正在设备上转写',
          };
          notifyListeners();
        },
        onProgress: (fraction) {
          progress = fraction;
          notifyListeners();
        },
      );
      final segments = (result['segments'] as List)
          .map((s) => Segment.fromJson(s as Map<String, dynamic>))
          .toList();
      await save(
        working.copyWith(
          status: TranscriptStatus.ready,
          segments: segments,
          durationMs: result['durationMs'] as int,
          clearError: true,
        ),
      );
    } catch (e) {
      final cancelled = e is EngineException && e.cancelled;
      error = cancelled ? null : e.toString();
      await save(
        working.copyWith(
          status: cancelled
              ? TranscriptStatus.interrupted
              : TranscriptStatus.failed,
          error: cancelled ? '转写已取消，音频已保留。' : '转写失败：$e',
        ),
      );
    } finally {
      taskId = null;
      phase = null;
      notifyListeners();
    }
  }

  Future<Transcript> createRevision(Transcript source) async {
    if (busy) throw StateError('请先结束当前任务');
    importing = true;
    phase = '正在准备新转写';
    notifyListeners();
    final id = const Uuid().v4();
    final path = p.join(
      root.path,
      'audio',
      '$id${p.extension(source.audioPath)}',
    );
    var persisted = false;
    try {
      await File(source.audioPath).copy(path);
      final revision = Transcript(
        id: id,
        title: '${source.title} · 新转写',
        createdAt: DateTime.now(),
        audioPath: path,
        durationMs: source.durationMs,
        language: language,
        prompt: prompt,
        source: source.source,
      );
      await save(revision);
      persisted = true;
      return revision;
    } finally {
      try {
        if (!persisted && await File(path).exists()) await File(path).delete();
      } finally {
        importing = false;
        phase = null;
        notifyListeners();
      }
    }
  }

  void cancelTranscription() => engine.cancel();

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_amplitude?.cancel());
    engine.cancel();
    unawaited(recorder.dispose());
    models.removeListener(_onModelsChanged);
    models.dispose();
    unawaited(repository.close());
    super.dispose();
  }
}
