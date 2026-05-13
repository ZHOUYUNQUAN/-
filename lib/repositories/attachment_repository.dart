import '../database/database_helper.dart';
import '../models/attachment.dart';

class AttachmentRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insert(Attachment attachment) async {
    final db = await _db.database;
    final map = attachment.toMap();
    map.remove('id');
    return await db.insert('attachments', map);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('attachments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Attachment>> getByRecordId(int recordId) async {
    final db = await _db.database;
    final maps = await db.query(
      'attachments',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );
    return maps.map((m) => Attachment.fromMap(m)).toList();
  }

  Future<List<Attachment>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('attachments');
    return maps.map((m) => Attachment.fromMap(m)).toList();
  }
}
