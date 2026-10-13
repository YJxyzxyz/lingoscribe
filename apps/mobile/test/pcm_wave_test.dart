import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_engine/pcm_wave.dart';

void main() {
  late Directory folder;
  setUp(() {
    folder = Directory.systemTemp.createTempSync('lingo-pcm-reader-');
  });
  tearDown(() {
    for (final file in folder.listSync().whereType<File>()) {
      file.deleteSync();
    }
    folder.deleteSync();
  });
  PcmWaveReader fixture(int samples) {
    final bytes = Uint8List(44 + samples * 2);
    final view = ByteData.sublistView(bytes);
    void tag(int offset, String value) {
      bytes.setRange(offset, offset + 4, value.codeUnits);
    }

    tag(0, 'RIFF');
    view.setUint32(4, bytes.length - 8, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, 1, Endian.little);
    view.setUint32(24, 16000, Endian.little);
    view.setUint32(28, 32000, Endian.little);
    view.setUint16(32, 2, Endian.little);
    view.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    view.setUint32(40, samples * 2, Endian.little);
    view.setInt16(bytes.length - 2, 32767, Endian.little);
    final file = File('${folder.path}/fixture.wav')..writeAsBytesSync(bytes);
    return PcmWaveReader.open(file.path);
  }

  test('full input retains the last sample beyond a whole millisecond', () {
    final reader = fixture(16001);
    try {
      expect(reader.durationMs, 1001);
      final actual = reader.readRange(0, reader.durationMs);
      expect(actual, hasLength(16001));
      expect(actual.last, closeTo(32767 / 32768, 0.000001));
      expect(() => reader.readRange(0, 1002), throwsFormatException);
    } finally {
      reader.close();
    }
  });
  test(
    '20-second bound includes no extra frames; trailing range stays readable',
    () {
      final reader = fixture(320001);
      try {
        expect(
          () => reader.readRange(0, reader.durationMs),
          throwsFormatException,
        );
        expect(reader.readRange(0, 20000), hasLength(320000));
        expect(
          reader.readRange(20000, 20001).single,
          closeTo(32767 / 32768, 0.000001),
        );
      } finally {
        reader.close();
      }
    },
  );
}
