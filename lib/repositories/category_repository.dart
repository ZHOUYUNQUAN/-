import '../database/database_helper.dart';
import '../models/category.dart';

class CategoryRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insert(Category category) async {
    final db = await _db.database;
    final map = category.toMap();
    map.remove('id');
    return await db.insert('categories', map);
  }

  Future<int> update(Category category) async {
    final db = await _db.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Category>> getAll({String? orderBy = 'sort_order ASC'}) async {
    final db = await _db.database;
    final maps = await db.query('categories', orderBy: orderBy);
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<List<Category>> getParents() async {
    final db = await _db.database;
    final maps = await db.query(
      'categories',
      where: 'parent_id IS NULL',
      orderBy: 'sort_order ASC',
    );
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<List<Category>> getChildren(int parentId) async {
    final db = await _db.database;
    final maps = await db.query(
      'categories',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<Category?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }
}
