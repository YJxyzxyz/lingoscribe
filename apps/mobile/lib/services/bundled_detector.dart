import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

Future<String> prepareSpeechDetector(Directory root) async {
  const name = 'ggml-silero-v6.2.0.bin';
  const expected =
      '2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987';
  final folder = Directory(p.join(root.path, 'models'));
  await folder.create(recursive: true);
  final file = File(p.join(folder.path, name));
  if (await file.exists() &&
      await file.length() == 885098 &&
      (await sha256.bind(file.openRead()).first).toString() == expected) {
    return file.path;
  }
  final data = await rootBundle.load('assets/models/$name');
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  if (bytes.length != 885098 || sha256.convert(bytes).toString() != expected) {
    throw const FormatException('内置语音检测模型校验失败');
  }
  final part = File('${file.path}.part');
  await part.writeAsBytes(bytes, flush: true);
  await part.rename(file.path);
  return file.path;
}
