import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

/// Bounded reads of the normalized private PCM file, including chunked WAVs.
/// Does not load a long recording into a Dart list.
class PcmWaveReader {
  PcmWaveReader._(this._file, this._offset, this.samples);
  final RandomAccessFile _file;
  final int _offset, samples;
  // Round the envelope up so the final fractional millisecond is accessible.
  int get durationMs => (samples + 15) ~/ 16;

  static PcmWaveReader open(String path) {
    final file = File(path).openSync();
    try {
      Uint8List read(int count) {
        final bytes = file.readSync(count);
        if (bytes.length != count) throw const FormatException('Truncated WAV');
        return bytes;
      }

      final header = read(12);
      if (String.fromCharCodes(header.sublist(0, 4)) != 'RIFF' ||
          String.fromCharCodes(header.sublist(8)) != 'WAVE') {
        throw const FormatException('Expected PCM WAV');
      }
      var formatted = false;
      while (file.positionSync() + 8 <= file.lengthSync()) {
        final chunk = read(8);
        final name = String.fromCharCodes(chunk.sublist(0, 4));
        final length = ByteData.sublistView(chunk).getUint32(4, Endian.little);
        final offset = file.positionSync();
        if (offset + length > file.lengthSync()) {
          throw const FormatException('Truncated WAV chunk');
        }
        if (name == 'fmt ') {
          if (length < 16) throw const FormatException('Invalid WAV format');
          final fmt = ByteData.sublistView(read(16));
          if (fmt.getUint16(0, Endian.little) != 1 ||
              fmt.getUint16(2, Endian.little) != 1 ||
              fmt.getUint32(4, Endian.little) != 16000 ||
              fmt.getUint16(12, Endian.little) != 2 ||
              fmt.getUint16(14, Endian.little) != 16) {
            throw const FormatException('Expected mono PCM16 16 kHz WAV');
          }
          formatted = true;
        } else if (name == 'data') {
          if (!formatted ||
              length == 0 ||
              length.isOdd ||
              length > 16000 * 2 * 7200) {
            throw const FormatException('Invalid or over-two-hour WAV');
          }
          return PcmWaveReader._(file, offset, length ~/ 2);
        }
        file.setPositionSync(offset + length + length % 2);
      }
      throw const FormatException('Missing WAV audio');
    } catch (_) {
      file.closeSync();
      rethrow;
    }
  }

  Float32List readRange(int startMs, int endMs) {
    final start = startMs * 16, end = math.min(endMs * 16, samples);
    if (start < 0 ||
        end <= start ||
        endMs > durationMs ||
        endMs - startMs > 20000 ||
        end - start > 16000 * 20) {
      throw const FormatException('Invalid speech interval');
    }
    _file.setPositionSync(_offset + start * 2);
    final bytes = _file.readSync((end - start) * 2);
    if (bytes.length != (end - start) * 2) {
      throw const FormatException('Truncated WAV audio');
    }
    final data = ByteData.sublistView(bytes);
    final result = Float32List(end - start);
    for (var i = 0; i < result.length; i++) {
      result[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return result;
  }

  void close() => _file.closeSync();
}
