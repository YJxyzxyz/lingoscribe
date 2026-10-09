import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoscribe/services/recording_recovery.dart';

void main() {
  test(
    'interrupted native zero header becomes a valid WAV without changing PCM',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lingoscribe-recovery',
      );
      try {
        final audio = Uint8List.fromList(List.generate(32000, (i) => i % 256));
        final file = File('${directory.path}/recording.wav');
        await file.writeAsBytes([...Uint8List(44), ...audio]);
        expect(await recoverRecording(file), 1000);
        final result = await file.readAsBytes();
        expect(result.length, 32044);
        expect(String.fromCharCodes(result.take(4)), 'RIFF');
        expect(
          ByteData.sublistView(result).getUint32(40, Endian.little),
          32000,
        );
        expect(result.sublist(44), audio);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
  test('unsupported or truncated containers are left untouched', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lingoscribe-recovery',
    );
    try {
      final file = File('${directory.path}/invalid.wav');
      await file.writeAsString('invalid audio');
      expect(await recoverRecording(file), isNull);
      expect(await file.readAsString(), 'invalid audio');
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
