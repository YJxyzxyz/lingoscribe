import 'dart:io';
import 'dart:typed_data';

/// Repairs only application-owned, interrupted PCM16 mono recording headers.
/// Real PCM is preserved; no audio samples or transcript text are fabricated.
Future<int?> recoverRecording(File file) async {
  if (!await file.exists()) return null;
  final length = await file.length();
  if (length < 44) return null;
  final handle = await file.open(mode: FileMode.append);
  try {
    await handle.setPosition(0);
    final bytes = await handle.read(length < 4096 ? length : 4096);
    if (bytes.length >= 44 && bytes.take(44).every((value) => value == 0)) {
      final size = length - 44 - (length - 44) % 2;
      if (size <= 0 || size > 16000 * 2 * 7200) return null;
      final repaired = Uint8List(44);
      final view = ByteData.sublistView(repaired);
      void code(int offset, String value) =>
          repaired.setRange(offset, offset + 4, value.codeUnits);
      code(0, 'RIFF');
      view.setUint32(4, size + 36, Endian.little);
      code(8, 'WAVE');
      code(12, 'fmt ');
      view.setUint32(16, 16, Endian.little);
      view.setUint16(20, 1, Endian.little);
      view.setUint16(22, 1, Endian.little);
      view.setUint32(24, 16000, Endian.little);
      view.setUint32(28, 32000, Endian.little);
      view.setUint16(32, 2, Endian.little);
      view.setUint16(34, 16, Endian.little);
      code(36, 'data');
      view.setUint32(40, size, Endian.little);
      await handle.setPosition(0);
      await handle.writeFrom(repaired);
      await handle.flush();
      return size ~/ 32;
    }
    final header = ByteData.sublistView(bytes);
    bool isCode(int at, String value) =>
        at + 4 <= bytes.length &&
        String.fromCharCodes(bytes.sublist(at, at + 4)) == value;
    if (!isCode(0, 'RIFF') || !isCode(8, 'WAVE')) return null;
    var offset = 12, pcm = false;
    while (offset + 8 <= bytes.length) {
      final size = header.getUint32(offset + 4, Endian.little);
      if (isCode(offset, 'fmt ') && size >= 16 && offset + 24 <= bytes.length) {
        pcm =
            header.getUint16(offset + 8, Endian.little) == 1 &&
            header.getUint16(offset + 10, Endian.little) == 1 &&
            header.getUint32(offset + 12, Endian.little) == 16000 &&
            header.getUint16(offset + 22, Endian.little) == 16;
      }
      if (isCode(offset, 'data')) {
        if (!pcm) return null;
        final available = length - offset - 8;
        final aligned = available - available % 2;
        if (aligned <= 0 || aligned > 16000 * 2 * 7200) return null;
        if (size == aligned &&
            header.getUint32(4, Endian.little) == length - 8) {
          return aligned ~/ 32;
        }
        final number = ByteData(4);
        number.setUint32(0, length - 8, Endian.little);
        await handle.setPosition(4);
        await handle.writeFrom(number.buffer.asUint8List());
        number.setUint32(0, aligned, Endian.little);
        await handle.setPosition(offset + 4);
        await handle.writeFrom(number.buffer.asUint8List());
        await handle.flush();
        return aligned ~/ 32;
      }
      offset += 8 + size + (size & 1);
    }
    return null;
  } finally {
    await handle.close();
  }
}
