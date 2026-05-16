import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static Future<Database>? _initFuture;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_initFuture != null) return _initFuture!;
    _initFuture = _initDatabase();
    try {
      _database = await _initFuture;
      return _database!;
    } finally {
      _initFuture = null;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expense_manager.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT '',
        parent_id INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (parent_id) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category_id INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        payment TEXT NOT NULL DEFAULT '微信',
        datetime TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE reimbursements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'pending',
        reimbursed_date TEXT,
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE
      )
    ''');

    await _seedCategories(db);
  }

  Future<void> _seedCategories(Database db) async {
    final seedData = [
      {'name': '餐饮', 'icon': '🍜', 'children': ['早餐', '午餐', '晚餐', '饮料零食']},
      {'name': '交通', 'icon': '🚗', 'children': ['打车', '公交地铁', '加油', '停车']},
      {'name': '购物', 'icon': '🛒', 'children': ['日用品', '服装', '数码', '其他']},
      {'name': '居住', 'icon': '🏠', 'children': ['房租', '水电', '物业', '网费']},
      {'name': '娱乐', 'icon': '🎬', 'children': ['电影', '游戏', '运动', '旅游']},
      {'name': '医疗', 'icon': '🏥', 'children': ['看病', '买药']},
      {'name': '办公', 'icon': '📄', 'children': ['文具', '打印', '快递']},
      {'name': '报销', 'icon': '🔄', 'children': []},
    ];

    int sort = 0;
    for (final parent in seedData) {
      final parentId = await db.insert('categories', {
        'name': parent['name'],
        'icon': parent['icon'],
        'parent_id': null,
        'sort_order': sort++,
      });
      int childSort = 0;
      for (final child in parent['children'] as List<String>) {
        await db.insert('categories', {
          'name': child,
          'icon': '',
          'parent_id': parentId,
          'sort_order': childSort++,
        });
      }
    }
  }
}
