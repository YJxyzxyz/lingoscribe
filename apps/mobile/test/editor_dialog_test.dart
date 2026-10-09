import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoscribe/ui/text_editor_dialog.dart';
import 'package:lingoscribe/ui/theme.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    bool rename = false,
    void Function(String?)? result,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final value = await showDialog<String>(
                  context: context,
                  builder: (_) => TextEditorDialog(
                    title: rename ? '重命名' : '校对',
                    initialText: '原文',
                    singleLine: rename,
                    requireNonempty: rename,
                  ),
                );
                result?.call(value);
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byType(TextEditorDialog), findsOneWidget);
  }

  testWidgets('saving edited text survives the dialog closing animation', (
    tester,
  ) async {
    String? saved;
    await open(tester, result: (value) => saved = value);
    await tester.enterText(find.byType(TextField), '已校对 mixed text');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved, '已校对 mixed text');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'dismissing with system back keeps controller alive until route disposal',
    (tester) async {
      await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TextEditorDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty names are rejected while the editor remains open', (
    tester,
  ) async {
    await open(tester, rename: true);
    await tester.enterText(find.byType(TextField), ' ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入标题'), findsOneWidget);
    expect(find.byType(TextEditorDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
