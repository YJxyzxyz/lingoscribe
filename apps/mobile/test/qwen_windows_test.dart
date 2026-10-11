import 'package:flutter_test/flutter_test.dart';
import 'package:offline_engine/qwen_windows.dart';

Map<String, dynamic> speech(int start, int end) => {
  'startMs': start,
  'endMs': end,
};

void main() {
  test('silence does not produce a decoding window', () {
    expect(qwenDecodeWindows([], 11000), isEmpty);
  });
  test(
    'short bilingual audio preserves input while timestamps cover speech',
    () {
      final windows = qwenDecodeWindows([
        speech(20, 1800),
        speech(2400, 3230),
      ], 3600);
      expect(windows, hasLength(1));
      final window = windows.single;
      expect([window.audioStartMs, window.audioEndMs], [0, 3600]);
      expect([window.startMs, window.endMs], [20, 3230]);
    },
  );
  test(
    'long audio windows stay bounded without reading neighbouring speech',
    () {
      final intervals = [
        speech(100, 19500),
        speech(19800, 22000),
        speech(22300, 25000),
        speech(26000, 46000),
      ];
      final windows = qwenDecodeWindows(intervals, 48000);
      expect(windows, hasLength(3));
      expect([windows[1].startMs, windows[1].endMs], [19800, 25000]);
      for (var index = 0; index < windows.length; index++) {
        final window = windows[index];
        expect(
          window.audioEndMs - window.audioStartMs,
          lessThanOrEqualTo(20000),
        );
        expect(window.audioStartMs, greaterThanOrEqualTo(0));
        expect(window.audioEndMs, lessThanOrEqualTo(48000));
        expect(window.audioStartMs, lessThanOrEqualTo(window.startMs));
        expect(window.audioEndMs, greaterThanOrEqualTo(window.endMs));
        if (index > 0) {
          expect(
            window.audioStartMs,
            greaterThanOrEqualTo(windows[index - 1].endMs),
          );
        }
        if (index + 1 < windows.length) {
          expect(
            window.audioEndMs,
            lessThanOrEqualTo(windows[index + 1].startMs),
          );
        }
      }
    },
  );
  test('invalid bounds fail before native model allocation', () {
    for (final intervals in [
      [speech(-1, 100)],
      [speech(10, 10)],
      [speech(0, 21000)],
      [speech(0, 200), speech(100, 300)],
      [speech(0, 50001)],
    ]) {
      expect(() => qwenDecodeWindows(intervals, 50000), throwsFormatException);
    }
  });
}
