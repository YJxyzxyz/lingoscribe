import 'dart:io';
import 'dart:ui' show ImageByteFormat;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoscribe/application/app_controller.dart';
import 'package:lingoscribe/data/transcript_repository.dart';
import 'package:lingoscribe/domain/transcript.dart';
import 'package:lingoscribe/services/model_manager.dart';
import 'package:lingoscribe/ui/app.dart';
import 'package:lingoscribe/ui/recording_screen.dart';
import 'package:lingoscribe/ui/detail_screen.dart';
import 'package:lingoscribe/ui/searchable_transcript_text.dart';
import 'package:lingoscribe/ui/model_bundle_import_dialog.dart';
import 'package:lingoscribe/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppController controller;
  late Directory directory;
  setUp(() async {
    // UI tests do not claim to exercise the microphone; native recording is tested on devices.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
    directory = await Directory.systemTemp.createTemp('lingoscribe-ui-test');
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final repository = await TranscriptRepository.open(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final modelManager = ModelManager(Directory('${directory.path}/models'));
    await modelManager.initialize(null);
    controller = AppController(
      repository: repository,
      root: directory,
      models: modelManager,
      preferences: await SharedPreferences.getInstance(),
    );
  });
  tearDown(() async {
    await controller.repository.close();
    controller.models.dispose();
    await directory.delete(recursive: true);
  });
  testWidgets(
    'empty library has no invented transcripts and opens genuine model management',
    (tester) async {
      await tester.pumpWidget(LingoScribeApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('给声音一个归处'), findsOneWidget);
      expect(find.text('0 条'), findsOneWidget);
      await tester.tap(find.text('离线模型'));
      await tester.pumpAndSettle();
      expect(find.text('下载 60 MB'), findsOneWidget);
      expect(find.text('下载 190 MB'), findsOneWidget);
      expect(find.text('当前使用'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real repository content is rendered and searchable from the library',
    (tester) async {
      await tester.runAsync(
        () => controller.save(
          Transcript(
            id: 'fixture',
            title: '自动化测试记录',
            createdAt: DateTime.utc(2026, 10, 9),
            audioPath: '/test/audio.wav',
            segments: const [
              Segment(startMs: 0, endMs: 1000, text: '今天 review 转写结果。'),
            ],
            status: TranscriptStatus.ready,
          ),
        ),
      );
      await tester.pumpWidget(LingoScribeApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('自动化测试记录'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '没有匹配');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('没有找到相关记录'), findsOneWidget);
      await tester.tap(find.byTooltip('清除搜索'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('自动化测试记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('320px viewport and large system font remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(LingoScribeApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'literal search highlights preserve selectable bilingual original text',
    (tester) async {
      const original = '学习 C++，c++ and Flutter。';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SearchableTranscriptText(text: original, query: 'C++'),
          ),
        ),
      );
      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.textSpan!.toPlainText(), original);
      final spans = text.textSpan!.children!.cast<TextSpan>();
      expect(
        spans
            .where((span) => span.style?.backgroundColor != null)
            .map((span) => span.text),
        ['C++', 'c++'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'per-record language and glossary save without altering defaults',
    (tester) async {
      final entry = Transcript(
        id: 'options',
        title: '待转写',
        createdAt: DateTime.now(),
        audioPath: '${directory.path}/options.wav',
      );
      await tester.runAsync(() => controller.save(entry));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DetailScreen(controller: controller, initial: entry),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('转写偏好'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'LingoScribe, Flutter');
      await tester.tap(find.text('保存选项'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      final saved = await tester.runAsync(() => controller.find(entry.id));
      expect(saved!.language, 'en');
      expect(saved.prompt, 'LingoScribe, Flutter');
      expect(controller.language, 'auto');
      expect(controller.prompt, '');
      expect(saved.segments, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'model files can be collected across folders without installing an incomplete bundle',
    (tester) async {
      final model = models.singleWhere((model) => model.engine == 'qwen3');
      List<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<List<String>>(
                    context: context,
                    builder: (_) => ModelBundleImportDialog(
                      model: model,
                      initialPaths: [
                        for (final asset in model.assets.take(3))
                          '/picked/models/${asset.path}',
                      ],
                      // File picker boundary only; actual model verification is exercised
                      // by model bundle tests and the real native integration pipeline.
                      pickMore: () async => [
                        for (final asset
                            in model.assets.skip(3).toList().reversed)
                          '/picked/${asset.path}',
                      ],
                    ),
                  );
                },
                child: const Text('Open import'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open import'));
      await tester.pumpAndSettle();
      expect(find.text('Verify and install'), findsNothing);
      expect(find.text('3 of 6 files selected'), findsOneWidget);
      await tester.tap(find.text('Add model files'));
      await tester.pumpAndSettle();
      expect(find.text('6 of 6 files selected'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Remove selected file').last);
      await tester.tap(find.byTooltip('Remove selected file').last);
      await tester.pumpAndSettle();
      expect(find.text('5 of 6 files selected'), findsOneWidget);
      expect(find.text('Verify and install'), findsNothing);
      await tester.tap(find.text('Add model files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify and install'));
      await tester.pumpAndSettle();
      expect(result, [
        for (final asset in model.assets)
          asset.path.startsWith('tokenizer/')
              ? '/picked/${asset.path}'
              : '/picked/models/${asset.path}',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'English interface switches persistently without altering bilingual records',
    (tester) async {
      await tester.runAsync(
        () => controller.save(
          Transcript(
            id: 'bilingual',
            title: '客户会议',
            createdAt: DateTime.now(),
            audioPath: '${directory.path}/bilingual.wav',
            status: TranscriptStatus.ready,
            segments: const [
              Segment(startMs: 0, endMs: 1000, text: '今天 review the plan.'),
            ],
          ),
        ),
      );
      await tester.runAsync(() => controller.setDisplayLanguage('en'));
      await tester.pumpWidget(LingoScribeApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('Your audio library'), findsOneWidget);
      expect(find.text('1 record'), findsOneWidget);
      expect(find.text('客户会议'), findsOneWidget);
      expect(find.text('今天 review the plan.'), findsOneWidget);
      await tester.tap(find.text('Offline models'));
      await tester.pumpAndSettle();
      expect(find.text('Download 60 MB'), findsOneWidget);
      expect(find.text('Light · Base'), findsOneWidget);
      await tester.runAsync(() => controller.setDisplayLanguage('zh'));
      await tester.pumpAndSettle();
      expect(find.text('把 AI 留在本机'), findsOneWidget);
      expect(controller.preferences.getString('displayLanguage'), 'zh');
      expect(
        (await tester.runAsync(() => controller.find('bilingual')))!.plainText,
        '今天 review the plan.',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('English library fits a narrow screen and large system font', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() => controller.setDisplayLanguage('en'));
    await tester.pumpWidget(LingoScribeApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Your audio library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'English detail remains usable with long titles and an open keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final entry = Transcript(
        id: 'detail-layout',
        title: List.filled(8, 'Long interview').join(' '),
        audioPath: '${directory.path}/missing-layout-only.wav',
        createdAt: DateTime.now(),
        durationMs: 1000,
        status: TranscriptStatus.ready,
        segments: const [
          Segment(startMs: 0, endMs: 1000, text: '校对 mixed text'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DetailScreen(controller: controller, initial: entry),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Search this transcript'), findsOneWidget);
      expect(find.text('校对 mixed text'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'known errors are localized while private device paths stay out of messages',
    (tester) async {
      late BuildContext scope;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              scope = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        friendlyError(scope, const FormatException('模型校验失败，请重新下载官方模型')),
        'Model verification failed. Download the official model again.',
      );
      final message = friendlyError(
        scope,
        const FileSystemException('Permission denied', '/private/personal.wav'),
      );
      expect(
        message,
        'Unable to access the file. Select it again and allow access.',
      );
      expect(message, isNot(contains('/private/')));
    },
  );
  testWidgets(
    'automatic recording limit opens the saved record after capture has ended',
    (tester) async {
      final recording = Transcript(
        id: 'recording-limit',
        title: '长录音',
        createdAt: DateTime.now(),
        audioPath: '${directory.path}/recording-limit.wav',
        status: TranscriptStatus.recording,
      );
      controller.recording = recording;
      await tester.pumpWidget(
        MaterialApp(home: RecordingScreen(controller: controller)),
      );
      await tester.pump();
      controller.recording = null;
      final saved = recording.copyWith(
        status: TranscriptStatus.saved,
        durationMs: 7200000,
      );
      controller.autoSavedRecording = saved;
      await tester.runAsync(() => controller.save(saved));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RecordingScreen), findsNothing);
      expect(find.byType(DetailScreen), findsOneWidget);
      expect(find.text('长录音'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  test(
    'native stop returning no path retains actual app-owned audio',
    () async {
      final file = File('${directory.path}/recording-recovery.wav');
      final pcm = List<int>.generate(32000, (i) => i % 256);
      await file.writeAsBytes([...List<int>.filled(44, 0), ...pcm]);
      final recording = Transcript(
        id: 'retained',
        title: '中断录音',
        createdAt: DateTime.now(),
        audioPath: file.path,
        status: TranscriptStatus.recording,
      );
      controller.recording = recording;
      await controller.repository.save(recording);
      final saved = await controller.stopRecording();
      expect(saved!.status, TranscriptStatus.interrupted);
      expect(saved.durationMs, 1000);
      expect((await file.readAsBytes()).sublist(44), pcm);
      expect(
        (await controller.find('retained'))!.status,
        TranscriptStatus.interrupted,
      );
    },
  );
  testWidgets('capture actual Flutter library render for visual QA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Optional local system font affects screenshots only, never ships in the application.
    final font = Platform.environment['LINGO_QA_FONT'];
    if (font != null) {
      await tester.runAsync(() async {
        final bytes = await File(font).readAsBytes();
        final loader = FontLoader('LingoQA')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      });
    }
    final icons = Platform.environment['LINGO_QA_ICONS'];
    if (icons != null) {
      await tester.runAsync(() async {
        final bytes = await File(icons).readAsBytes();
        final loader = FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      });
    }
    const key = ValueKey('capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: LingoScribeApp(
          controller: controller,
          fontFamily: font == null ? null : 'LingoQA',
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (Platform.environment['LINGO_CAPTURE_UI'] == '1') {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ImageByteFormat.png);
        final output = File(
          Platform.environment['LINGO_UI_CAPTURE_PATH'] ??
              '../../docs/validation/library-flutter.png',
        );
        await output.parent.create(recursive: true);
        await output.writeAsBytes(data!.buffer.asUint8List());
      });
    }
    expect(tester.takeException(), isNull);
  });
}
