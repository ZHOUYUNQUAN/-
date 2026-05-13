import '../database/database_helper.dart';
import '../models/reimbursement.dart';

class ReimbursementRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insert(Reimbursement reimbursement) async {
    final db = await _db.database;
    final map = reimbursement.toMap();
    map.remove('id');
    return await db.insert('reimbursements', map);
  }

  Future<int> markAsDone(int id, String date) async {
    final db = await _db.database;
    return await db.update(
      'reimbursements',
      {'status': 'done', 'reimbursed_date': date},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Reimbursement>> getPending() async {
    final db = await _db.database;
    final maps = await db.query(
      'reimbursements',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
    return maps.map((m) => Reimbursement.fromMap(m)).toList();
  }

  Future<List<Reimbursement>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('reimbursements', orderBy: 'id DESC');
    return maps.map((m) => Reimbursement.fromMap(m)).toList();
  }

  Future<Reimbursement?> getByRecordId(int recordId) async {
    final db = await _db.database;
    final maps = await db.query(
      'reimbursements',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );
    if (maps.isEmpty) return null;
    return Reimbursement.fromMap(maps.first);
  }

  Future<double> getPendingTotal() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT SUM(r.amount) as total
      FROM records r
      INNER JOIN reimbursements rb ON r.id = rb.record_id
      WHERE rb.status = 'pending'
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
