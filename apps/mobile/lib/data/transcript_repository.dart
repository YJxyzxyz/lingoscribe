import 'package:sqflite/sqflite.dart';
import '../domain/transcript.dart';

class TranscriptRepository {
  TranscriptRepository(this.database);
  final Database database;
  static Future<TranscriptRepository> open(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            '''CREATE TABLE transcripts (
          id TEXT PRIMARY KEY, title TEXT NOT NULL, createdAt INTEGER NOT NULL,
          audioPath TEXT NOT NULL, durationMs INTEGER NOT NULL, status TEXT NOT NULL,
          segments TEXT NOT NULL, plainText TEXT NOT NULL, language TEXT NOT NULL,
          prompt TEXT NOT NULL, modelId TEXT, error TEXT, source TEXT NOT NULL)''',
          );
          await db.execute(
            'CREATE INDEX transcripts_created ON transcripts(createdAt DESC)',
          );
        },
      ),
    );
    await db.rawUpdate(
      "UPDATE transcripts SET status = 'interrupted', error = ? WHERE status IN ('transcribing', 'recording')",
      ['任务被中断，音频已保留，请重试。'],
    );
    return TranscriptRepository(db);
  }

  Future<void> save(Transcript value) async => database.insert(
    'transcripts',
    value.toRow(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  Future<List<Transcript>> list({String query = ''}) async {
    final escaped = query
        .trim()
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final rows = await database.query(
      'transcripts',
      where: escaped.isEmpty
          ? null
          : "title LIKE ? ESCAPE '\\' OR plainText LIKE ? ESCAPE '\\'",
      whereArgs: escaped.isEmpty ? null : ['%$escaped%', '%$escaped%'],
      orderBy: 'createdAt DESC',
    );
    return rows.map(Transcript.fromRow).toList();
  }

  Future<void> delete(String id) async =>
      database.delete('transcripts', where: 'id = ?', whereArgs: [id]);
  Future<Transcript?> get(String id) async {
    final rows = await database.query(
      'transcripts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Transcript.fromRow(rows.single);
  }

  Future<void> close() => database.close();
}
