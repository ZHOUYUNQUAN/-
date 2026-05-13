import '../database/database_helper.dart';
import '../models/record.dart';

class RecordRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insert(Record record) async {
    final db = await _db.database;
    final map = record.toMap();
    map.remove('id');
    return await db.insert('records', map);
  }

  Future<int> update(Record record) async {
    final db = await _db.database;
    return await db.update(
      'records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('records', where: 'id = ?', whereArgs: [id]);
  }

  Future<Record?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query('records', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Record.fromMap(maps.first);
  }

  Future<List<Record>> getAll({String? orderBy = 'datetime DESC'}) async {
    final db = await _db.database;
    final maps = await db.query('records', orderBy: orderBy);
    return maps.map((m) => Record.fromMap(m)).toList();
  }

  Future<List<Record>> getByMonth(int year, int month) async {
    final db = await _db.database;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'records',
      where: 'datetime LIKE ?',
      whereArgs: ['$prefix%'],
      orderBy: 'datetime DESC',
    );
    return maps.map((m) => Record.fromMap(m)).toList();
  }

  Future<List<Record>> getByDate(String date) async {
    final db = await _db.database;
    final maps = await db.query(
      'records',
      where: 'datetime LIKE ?',
      whereArgs: ['$date%'],
      orderBy: 'datetime DESC',
    );
    return maps.map((m) => Record.fromMap(m)).toList();
  }

  Future<double> getMonthTotal(int year, int month) async {
    final records = await getByMonth(year, month);
    double total = 0;
    for (final r in records) {
      total += r.amount;
    }
    return total;
  }
}
