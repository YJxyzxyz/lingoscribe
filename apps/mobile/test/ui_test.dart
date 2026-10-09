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
        final output = File('../../docs/validation/library-flutter.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(data!.buffer.asUint8List());
      });
    }
    expect(tester.takeException(), isNull);
  });
}
