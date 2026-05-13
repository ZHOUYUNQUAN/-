# 个人支出管理 App 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Flutter Android 个人支出管理 App，支持手动记账、截图 OCR 识别、报销管理、报表展示、CSV/ZIP 导出导入。

**Architecture:** 分层架构 — Model → Repository → Service → UI。数据层使用 sqflite 纯本地存储，OCR 使用 Google ML Kit 离线识别。每层职责清晰，可独立开发测试。

**Tech Stack:** Flutter 3.x + Dart, sqflite, google_mlkit_text_recognition, fl_chart, csv, archive (ZIP)

---

## 文件结构

```
expense-manager/
├── lib/
│   ├── main.dart                          # 入口
│   ├── app.dart                           # MaterialApp + 底部导航
│   ├── models/
│   │   ├── record.dart                    # Record 数据模型
│   │   ├── category.dart                  # Category 数据模型
│   │   ├── reimbursement.dart             # Reimbursement 数据模型
│   │   └── attachment.dart                # Attachment 数据模型
│   ├── database/
│   │   ├── database_helper.dart           # SQLite 初始化 + 建表
│   │   └── seed_data.dart                 # 预设分类种子数据
│   ├── repositories/
│   │   ├── record_repository.dart         # 支出记录 CRUD
│   │   ├── category_repository.dart       # 分类 CRUD
│   │   ├── reimbursement_repository.dart  # 报销 CRUD
│   │   └── attachment_repository.dart     # 附件 CRUD
│   ├── services/
│   │   ├── ocr_service.dart               # OCR 文字识别
│   │   ├── screenshot_service.dart        # 截图监听
│   │   ├── export_service.dart            # CSV/ZIP 导出
│   │   └── import_service.dart            # ZIP 导入恢复
│   ├── pages/
│   │   ├── home_page.dart                 # 首页
│   │   ├── records_page.dart              # 记账流水页
│   │   ├── add_record_page.dart           # 新增记账表单页
│   │   ├── report_page.dart               # 报表页
│   │   ├── settings_page.dart             # 设置页
│   │   └── reimbursement_list_page.dart   # 报销列表页
│   └── widgets/
│       ├── category_selector.dart         # 类别选择器
│       ├── payment_selector.dart          # 支付方式选择器
│       ├── record_card.dart               # 单条记录卡片
│       └── statistic_card.dart            # 统计汇总卡片
```

---

## 阶段一：项目搭建与数据层（Foundation）

### 任务 1：Flutter 项目脚手架与环境配置

**前置条件：** 已安装 Flutter SDK、Android Studio

**Files:**
- Create: `expense-manager/` (flutter create)
- Modify: `pubspec.yaml`

- [ ] **Step 1: 创建 Flutter 项目**

Run:
```bash
cd /Users/a33333/Projects
flutter create --org com.yingfeng expense-manager
cd expense-manager
```

Expected: Flutter 项目脚手架生成，`lib/main.dart` 存在。

- [ ] **Step 2: 配置 pubspec.yaml 依赖**

修改 `pubspec.yaml` 的 `dependencies` 部分：

```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  path: ^1.8.3
  path_provider: ^2.1.1
  google_mlkit_text_recognition: ^0.13.0
  image_picker: ^1.0.4
  fl_chart: ^0.68.0
  csv: ^6.0.0
  archive: ^3.4.9
  intl: ^0.19.0
  provider: ^6.1.1
  permission_handler: ^11.1.0
  file_picker: ^8.0.0
```

Run:
```bash
flutter pub get
```

Expected: 依赖安装成功，无报错。

- [ ] **Step 3: 创建目录结构**

```bash
mkdir -p lib/models lib/database lib/repositories lib/services lib/pages lib/widgets
```

Expected: 目录结构创建完成。

- [ ] **Step 4: 验证项目可构建**

```bash
flutter build apk --debug
```

Expected: APK 构建成功无报错。

- [ ] **Step 5: 提交**

```bash
git init
git add .
git commit -m "chore: scaffold Flutter project with dependencies"
```

---

### 任务 2：数据模型（Models）

**Files:**
- Create: `lib/models/record.dart`
- Create: `lib/models/category.dart`
- Create: `lib/models/reimbursement.dart`
- Create: `lib/models/attachment.dart`

- [ ] **Step 1: 实现 Record 模型**

`lib/models/record.dart`：

```dart
class Record {
  final int? id;
  final double amount;
  final int categoryId;
  final String note;
  final String payment;   // 微信/支付宝/现金/银行卡
  final String datetime;  // yyyy-MM-dd HH:mm:ss
  final String createdAt;

  Record({
    this.id,
    required this.amount,
    required this.categoryId,
    this.note = '',
    this.payment = '微信',
    required this.datetime,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'category_id': categoryId,
    'note': note,
    'payment': payment,
    'datetime': datetime,
    'created_at': createdAt,
  };

  factory Record.fromMap(Map<String, dynamic> map) => Record(
    id: map['id'] as int?,
    amount: (map['amount'] as num).toDouble(),
    categoryId: map['category_id'] as int,
    note: map['note'] as String? ?? '',
    payment: map['payment'] as String? ?? '微信',
    datetime: map['datetime'] as String,
    createdAt: map['created_at'] as String?,
  );

  Record copyWith({
    int? id,
    double? amount,
    int? categoryId,
    String? note,
    String? payment,
    String? datetime,
    String? createdAt,
  }) => Record(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    categoryId: categoryId ?? this.categoryId,
    note: note ?? this.note,
    payment: payment ?? this.payment,
    datetime: datetime ?? this.datetime,
    createdAt: createdAt ?? this.createdAt,
  );
}
```

- [ ] **Step 2: 实现 Category 模型**

`lib/models/category.dart`：

```dart
class Category {
  final int? id;
  final String name;
  final String icon;
  final int? parentId;
  final int sortOrder;

  Category({
    this.id,
    required this.name,
    this.icon = '',
    this.parentId,
    this.sortOrder = 0,
  });

  bool get isParent => parentId == null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'parent_id': parentId,
    'sort_order': sortOrder,
  };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id'] as int?,
    name: map['name'] as String,
    icon: map['icon'] as String? ?? '',
    parentId: map['parent_id'] as int?,
    sortOrder: map['sort_order'] as int? ?? 0,
  );

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    int? parentId,
    int? sortOrder,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    parentId: parentId ?? this.parentId,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}
```

- [ ] **Step 3: 实现 Reimbursement 模型**

`lib/models/reimbursement.dart`：

```dart
class Reimbursement {
  final int? id;
  final int recordId;
  final String status;  // pending / done
  final String? reimbursedDate;
  final String note;

  Reimbursement({
    this.id,
    required this.recordId,
    this.status = 'pending',
    this.reimbursedDate,
    this.note = '',
  });

  bool get isPending => status == 'pending';
  bool get isDone => status == 'done';

  Map<String, dynamic> toMap() => {
    'id': id,
    'record_id': recordId,
    'status': status,
    'reimbursed_date': reimbursedDate,
    'note': note,
  };

  factory Reimbursement.fromMap(Map<String, dynamic> map) => Reimbursement(
    id: map['id'] as int?,
    recordId: map['record_id'] as int,
    status: map['status'] as String? ?? 'pending',
    reimbursedDate: map['reimbursed_date'] as String?,
    note: map['note'] as String? ?? '',
  );
}
```

- [ ] **Step 4: 实现 Attachment 模型**

`lib/models/attachment.dart`：

```dart
class Attachment {
  final int? id;
  final int recordId;
  final String filePath;
  final String createdAt;

  Attachment({
    this.id,
    required this.recordId,
    required this.filePath,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'record_id': recordId,
    'file_path': filePath,
    'created_at': createdAt,
  };

  factory Attachment.fromMap(Map<String, dynamic> map) => Attachment(
    id: map['id'] as int?,
    recordId: map['record_id'] as int,
    filePath: map['file_path'] as String,
    createdAt: map['created_at'] as String?,
  );
}
```

- [ ] **Step 5: 提交**

```bash
git add lib/models/
git commit -m "feat: add data models for Record, Category, Reimbursement, Attachment"
```

---

### 任务 3：数据库初始化与种子数据

**Files:**
- Create: `lib/database/database_helper.dart`
- Create: `lib/database/seed_data.dart`

- [ ] **Step 1: 实现数据库帮助类**

`lib/database/database_helper.dart`：

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
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

    // 插入预设分类
    await _seedCategories(db);
  }

  Future<void> _seedCategories(Database db) async {
    final seedData = [
      { 'name': '餐饮',   'icon': '🍜', 'children': ['早餐', '午餐', '晚餐', '饮料零食'] },
      { 'name': '交通',   'icon': '🚗', 'children': ['打车', '公交地铁', '加油', '停车'] },
      { 'name': '购物',   'icon': '🛒', 'children': ['日用品', '服装', '数码', '其他'] },
      { 'name': '居住',   'icon': '🏠', 'children': ['房租', '水电', '物业', '网费'] },
      { 'name': '娱乐',   'icon': '🎬', 'children': ['电影', '游戏', '运动', '旅游'] },
      { 'name': '医疗',   'icon': '🏥', 'children': ['看病', '买药'] },
      { 'name': '办公',   'icon': '📄', 'children': ['文具', '打印', '快递'] },
      { 'name': '报销',   'icon': '🔄', 'children': [] },
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
```

- [ ] **Step 2: 提交**

```bash
git add lib/database/
git commit -m "feat: add database helper with schema and seed data"
```

---

### 任务 4：数据中心仓库层（Repositories）

**Files:**
- Create: `lib/repositories/record_repository.dart`
- Create: `lib/repositories/category_repository.dart`
- Create: `lib/repositories/reimbursement_repository.dart`
- Create: `lib/repositories/attachment_repository.dart`

- [ ] **Step 1: 实现 RecordRepository**

`lib/repositories/record_repository.dart`：

```dart
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/record.dart';

class RecordRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insert(Record record) async {
    final db = await _db.database;
    return await db.insert('records', record.toMap()..remove('id'));
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
    return records.fold(0.0, (sum, r) => sum + r.amount);
  }
}
```

- [ ] **Step 2: 实现 CategoryRepository**

`lib/repositories/category_repository.dart`：

```dart
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/category.dart';

class CategoryRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insert(Category category) async {
    final db = await _db.database;
    return await db.insert('categories', category.toMap()..remove('id'));
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
```

- [ ] **Step 3: 实现 ReimbursementRepository**

`lib/repositories/reimbursement_repository.dart`：

```dart
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/reimbursement.dart';

class ReimbursementRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insert(Reimbursement reimbursement) async {
    final db = await _db.database;
    return await db.insert('reimbursements', reimbursement.toMap()..remove('id'));
  }

  Future<int> markAsDone(int id, String date) async {
    final db = await _db.database;
    return await db.update(
      'reimbursements',
      { 'status': 'done', 'reimbursed_date': date },
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
```

- [ ] **Step 4: 实现 AttachmentRepository**

`lib/repositories/attachment_repository.dart`：

```dart
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/attachment.dart';

class AttachmentRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> insert(Attachment attachment) async {
    final db = await _db.database;
    return await db.insert('attachments', attachment.toMap()..remove('id'));
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
```

- [ ] **Step 5: 提交**

```bash
git add lib/repositories/
git commit -m "feat: add repositories for records, categories, reimbursements, attachments"
```

---

## 阶段二：服务层（Services）

### 任务 5：OCR 识别服务

**Files:**
- Create: `lib/services/ocr_service.dart`

- [ ] **Step 1: 实现 OCR 服务**

`lib/services/ocr_service.dart`：

```dart
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final double? amount;
  final String? merchant;
  final String? datetime;
  final String? category;
  final String? payment;

  OcrResult({
    this.amount,
    this.merchant,
    this.datetime,
    this.category,
    this.payment,
  });

  bool get hasAny => amount != null || merchant != null || datetime != null || payment != null;
}

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer();

  Future<OcrResult> recognize(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _recognizer.processImage(inputImage);

    String fullText = recognizedText.text;
    double? amount;
    String? merchant;
    String? datetime;
    String? payment;

    // 提取金额：匹配 "¥" 或 "￥" 开头或前面的数字
    final amountRegex = RegExp(r'[实付|合计|金额|¥|￥]\s*(\d+\.?\d*)');
    final amountMatch = amountRegex.firstMatch(fullText);
    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(1)!);
    }
    if (amount == null) {
      // 尝试直接匹配 ¥ 符号
      final simpleRegex = RegExp(r'[¥￥](\d+\.\d{2})');
      final simpleMatch = simpleRegex.firstMatch(fullText);
      if (simpleMatch != null) {
        amount = double.tryParse(simpleMatch.group(1)!);
      }
    }

    // 提取支付方式
    if (fullText.contains('微信') || fullText.contains('WeChat')) {
      payment = '微信';
    } else if (fullText.contains('支付宝') || fullText.contains('Alipay')) {
      payment = '支付宝';
    }

    // 提取时间：yyyy-MM-dd HH:mm 或 yyyy年MM月dd日 HH:mm
    final timeRegex = RegExp(r'(\d{4}[-年]\d{1,2}[-月]\d{1,2})\s*(\d{1,2}:\d{2})');
    final timeMatch = timeRegex.firstMatch(fullText);
    if (timeMatch != null) {
      final date = timeMatch.group(1)!
          .replaceAll('年', '-')
          .replaceAll('月', '-')
          .replaceAll('日', '');
      datetime = '$date ${timeMatch.group(2)}:00';
    }

    // 提取商户名（取第一行非金额非时间的文字作为商户）
    final lines = fullText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (final line in lines) {
      if (line.length >= 2 &&
          line.length <= 20 &&
          !line.contains(RegExp(r'[¥￥\d:]')) &&
          line != payment) {
        merchant = line;
        break;
      }
    }

    // 类别关键词匹配（result 中只返回匹配到的关键词，UI 层做具体分类 ID 映射）
    final categoryKeywords = {
      '餐饮': ['餐', '饭', '吃', '食堂', '外卖', '午餐', '早餐', '晚餐', '美食', 'KFC', '麦当劳', '星巴克'],
      '交通': ['打车', '滴滴', '公交', '地铁', '加油', '停车', '高铁', '机票', '出租车'],
      '购物': ['超市', '商场', '淘宝', '京东', '拼多多', '便利店', '百货'],
      '娱乐': ['电影', '游戏', 'KTV', '健身', '旅游', '酒店', '门票'],
      '医疗': ['医院', '药店', '医药', '诊所', '体检'],
      '居住': ['房租', '水电', '物业', '燃气'],
    };
    outer:
    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (fullText.contains(keyword)) {
          // 这里只记录匹配到的关键词分类名，UI 层再映射到具体的分类 ID
          break outer;
        }
      }
    }

    return OcrResult(
      amount: amount,
      merchant: merchant,
      datetime: datetime,
      payment: payment,
    );
  }

  void dispose() {
    _recognizer.close();
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/services/ocr_service.dart
git commit -m "feat: add OCR recognition service"
```

---

### 任务 6：截图监听服务

**Files:**
- Create: `lib/services/screenshot_service.dart`

- [ ] **Step 1: 实现截图监听服务**

`lib/services/screenshot_service.dart`：

```dart
import 'dart:async';
import 'package:flutter/material.dart';
// 注意：Android 原生截图监听需要 PlatformChannel 实现
// 这里提供抽象接口供 UI 层调用

class ScreenshotService {
  static const _channel = MethodChannel('com.yingfeng.expense/screenshot');

  /// 注册截图监听回调
  Future<void> startListening(VoidCallback onScreenshot) async {
    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onScreenshotTaken') {
          onScreenshot();
        }
      });
    } catch (e) {
      // 截图监听不可用时静默失败
    }
  }

  Future<void> stopListening() async {
    try {
      _channel.setMethodCallHandler(null);
    } catch (e) {
      // ignore
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/services/screenshot_service.dart
git commit -m "feat: add screenshot monitoring service"
```

---

### 任务 7：导出导入服务

**Files:**
- Create: `lib/services/export_service.dart`
- Create: `lib/services/import_service.dart`

- [ ] **Step 1: 实现导出服务（CSV + ZIP）**

`lib/services/export_service.dart`：

```dart
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import '../models/category.dart';
import '../models/reimbursement.dart';
import '../models/attachment.dart';
import '../repositories/record_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/reimbursement_repository.dart';
import '../repositories/attachment_repository.dart';

class ExportService {
  final RecordRepository _recordRepo = RecordRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final ReimbursementRepository _reimbRepo = ReimbursementRepository();
  final AttachmentRepository _attachmentRepo = AttachmentRepository();

  Future<String> export({bool includeImages = true}) async {
    final records = await _recordRepo.getAll();
    final categories = await _categoryRepo.getAll();
    final reimbursements = await _reimbRepo.getAll();
    final attachments = await _attachmentRepo.getAll();

    final categoryMap = {for (final c in categories) c.id!: c};
    final reimbMap = {for (final r in reimbursements) r.recordId: r};
    final attachmentMap = <int, List<Attachment>>{};
    for (final a in attachments) {
      attachmentMap.putIfAbsent(a.recordId, () => []).add(a);
    }

    // Build CSV rows
    final header = <String>['ID', '金额', '类别', '子类别', '备注', '支付方式', '时间', '报销状态', '截图数'];
    final rows = <List<String>>[header];

    for (final record in records) {
      final cat = categoryMap[record.categoryId];
      final parentCat = cat?.parentId != null ? categoryMap[cat!.parentId!] : null;
      final reimb = reimbMap[record.id];
      final atts = attachmentMap[record.id] ?? [];

      rows.add([
        record.id.toString(),
        record.amount.toStringAsFixed(2),
        parentCat?.name ?? cat?.name ?? '',
        cat?.parentId != null ? cat!.name : '',
        record.note,
        record.payment,
        record.datetime,
        reimb?.status == 'done' ? '已报销' : (reimb != null ? '待报销' : ''),
        atts.length.toString(),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dir = await getApplicationDocumentsDirectory();

    if (includeImages && attachments.isNotEmpty) {
      // ZIP: CSV + images folder
      final archive = Archive();
      archive.addFile(ArchiveFile('expenses.csv', csvData.length, utf8.encode(csvData)));

      // Add all attachment images
      final processedPaths = <String>{};
      for (final att in attachments) {
        final file = File(att.filePath);
        if (await file.exists() && !processedPaths.contains(att.filePath)) {
          processedPaths.add(att.filePath);
          final bytes = await file.readAsBytes();
          final fileName = 'images/${att.recordId}_${att.id}${_getExtension(att.filePath)}';
          archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
        }
      }

      final zipBytes = ZipEncoder().encode(archive);
      final zipFile = File('${dir.path}/expenses_$timestamp.zip');
      await zipFile.writeAsBytes(zipBytes!);
      return zipFile.path;
    } else {
      // CSV only
      final csvFile = File('${dir.path}/expenses_$timestamp.csv');
      await csvFile.writeAsString(csvData);
      return csvFile.path;
    }
  }

  String _getExtension(String path) {
    final ext = path.split('.').last;
    return '.${ext.length <= 4 ? ext : 'jpg'}';
  }
}
```

- [ ] **Step 2: 实现导入服务**

`lib/services/import_service.dart`：

```dart
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../repositories/record_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/reimbursement_repository.dart';
import '../repositories/attachment_repository.dart';
import '../models/record.dart';
import '../models/reimbursement.dart';
import '../models/attachment.dart';

class ImportResult {
  final int recordsImported;
  final int imagesImported;
  final String message;

  ImportResult({
    required this.recordsImported,
    required this.imagesImported,
    required this.message,
  });
}

class ImportService {
  final RecordRepository _recordRepo = RecordRepository();
  final ReimbursementRepository _reimbRepo = ReimbursementRepository();
  final AttachmentRepository _attachmentRepo = AttachmentRepository();

  Future<ImportResult> importFromZip(String zipPath) async {
    final file = File(zipPath);
    if (!await file.exists()) {
      return ImportResult(recordsImported: 0, imagesImported: 0, message: '文件不存在');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${dir.path}/imported_images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }

    // Extract CSV
    ArchiveFile? csvFile;
    final imageFiles = <ArchiveFile>[];

    for (final entry in archive) {
      if (entry.isFile) {
        if (entry.name == 'expenses.csv') {
          csvFile = entry;
        } else if (entry.name.startsWith('images/')) {
          imageFiles.add(entry);
        }
      }
    }

    if (csvFile == null) {
      return ImportResult(recordsImported: 0, imagesImported: 0, message: 'ZIP 中未找到 expenses.csv');
    }

    // Parse CSV
    final csvContent = utf8.decode(csvFile.content);
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.isEmpty) {
      return ImportResult(recordsImported: 0, imagesImported: 0, message: 'CSV 为空');
    }

    int recordCount = 0;
    int imageCount = 0;

    // Skip header row, import data
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 7) continue;

      try {
        final recordId = await _recordRepo.insert(Record(
          amount: (row[1] as num).toDouble(),
          categoryId: _resolveCategoryId(row[2] as String, row[3] as String),
          note: row[4] as String? ?? '',
          payment: row[5] as String? ?? '微信',
          datetime: row[6] as String,
        ));

        // Import reimbursement status
        final reimbStatus = row[7] as String? ?? '';
        if (reimbStatus.isNotEmpty) {
          await _reimbRepo.insert(Reimbursement(
            recordId: recordId,
            status: reimbStatus == '已报销' ? 'done' : 'pending',
          ));
        }

        recordCount++;
      } catch (e) {
        // Skip invalid rows
      }
    }

    // Save images
    for (final imgFile in imageFiles) {
      final targetPath = '${imageDir.path}/${imgFile.name.replaceFirst('images/', '')}';
      await File(targetPath).writeAsBytes(imgFile.content);
      imageCount++;
    }

    return ImportResult(
      recordsImported: recordCount,
      imagesImported: imageCount,
      message: '成功导入 $recordCount 条记录，$imageCount 张图片',
    );
  }

  int _resolveCategoryId(String parentName, String childName) {
    // 在导入时根据名称查找匹配的分类ID
    // 简化实现：后续可以使用 CategoryRepository 查找
    return 1; // 默认归入第一个类别
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/services/export_service.dart lib/services/import_service.dart
git commit -m "feat: add CSV export and ZIP import services"
```

---

## 阶段三：UI 组件层（Widgets）

### 任务 8：通用 UI 组件

**Files:**
- Create: `lib/widgets/category_selector.dart`
- Create: `lib/widgets/payment_selector.dart`
- Create: `lib/widgets/record_card.dart`
- Create: `lib/widgets/statistic_card.dart`

- [ ] **Step 1: 实现 CategorySelector**

`lib/widgets/category_selector.dart`：

```dart
import 'package:flutter/material.dart';
import '../models/category.dart';

class CategorySelector extends StatelessWidget {
  final List<Category> parentCategories;
  final List<Category> childCategories;
  final int? selectedParentId;
  final int? selectedChildId;
  final ValueChanged<int> onParentSelected;
  final ValueChanged<int?> onChildSelected;

  const CategorySelector({
    super.key,
    required this.parentCategories,
    required this.childCategories,
    this.selectedParentId,
    this.selectedChildId,
    required this.onParentSelected,
    this.onChildSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 一级类别
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: parentCategories.map((cat) {
            final isSelected = cat.id == selectedParentId;
            return GestureDetector(
              onTap: () => onParentSelected(cat.id!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.green : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${cat.icon} ${cat.name}',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.green : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (childCategories.isNotEmpty) ...[
          const SizedBox(height: 8),
          // 子类别
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: childCategories.map((cat) {
              final isSelected = cat.id == selectedChildId;
              return GestureDetector(
                onTap: () => onChildSelected?.call(cat.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2: 实现 PaymentSelector**

`lib/widgets/payment_selector.dart`：

```dart
import 'package:flutter/material.dart';

class PaymentSelector extends StatelessWidget {
  final String selectedPayment;
  final ValueChanged<String> onChanged;

  static const payments = ['微信', '支付宝', '现金', '银行卡'];

  const PaymentSelector({
    super.key,
    required this.selectedPayment,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: payments.map((payment) {
        final isSelected = payment == selectedPayment;
        return GestureDetector(
          onTap: () => onChanged(payment),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _iconFor(payment) + ' ' + payment,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.green : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _iconFor(String payment) {
    switch (payment) {
      case '微信': return '💳';
      case '支付宝': return '💳';
      case '现金': return '💵';
      case '银行卡': return '💳';
      default: return '💳';
    }
  }
}
```

- [ ] **Step 3: 实现 RecordCard**

`lib/widgets/record_card.dart`：

```dart
import 'package:flutter/material.dart';
import '../models/record.dart';

class RecordCard extends StatelessWidget {
  final Record record;
  final String categoryName;
  final String categoryIcon;
  final bool isReimbursing;
  final bool hasAttachment;
  final VoidCallback? onTap;

  const RecordCard({
    super.key,
    required this.record,
    required this.categoryName,
    required this.categoryIcon,
    this.isReimbursing = false,
    this.hasAttachment = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Text(categoryIcon, style: const TextStyle(fontSize: 20)),
        ),
        title: Text('$categoryIcon $categoryName',
          style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          record.note.isNotEmpty ? record.note : record.payment,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '-¥${record.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isReimbursing)
                  const Text('🔄 ', style: TextStyle(fontSize: 10)),
                if (hasAttachment)
                  const Text('📎 ', style: TextStyle(fontSize: 10)),
                Text(
                  _formatTime(record.datetime),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dt) {
    if (dt.length >= 16) return dt.substring(11, 16);
    return dt;
  }
}
```

- [ ] **Step 4: 实现 StatisticCard**

`lib/widgets/statistic_card.dart`：

```dart
import 'package:flutter/material.dart';

class StatisticCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color? color;

  const StatisticCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (color ?? Colors.green).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 提交**

```bash
git add lib/widgets/
git commit -m "feat: add shared UI widgets"
```

---

## 阶段四：页面层（Pages）

### 任务 9：App 主入口与底部导航

**Files:**
- Create: `lib/main.dart`（替换默认）
- Create: `lib/app.dart`

- [ ] **Step 1: 更新 main.dart**

`lib/main.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExpenseApp());
}
```

- [ ] **Step 2: 实现 App Shell + 底部导航**

`lib/app.dart`：

```dart
import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/records_page.dart';
import 'pages/report_page.dart';
import 'pages/settings_page.dart';

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '个人支出管理',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    RecordsPage(),
    ReportPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: '记账'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: '报表'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/main.dart lib/app.dart
git commit -m "feat: add app entry point and bottom navigation shell"
```

---

### 任务 10：首页（HomePage）

**Files:**
- Create: `lib/pages/home_page.dart`

- [ ] **Step 1: 实现首页**

`lib/pages/home_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/statistic_card.dart';
import '../widgets/record_card.dart';
import '../repositories/record_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/reimbursement_repository.dart';
import '../models/record.dart';
import '../models/category.dart';
import 'add_record_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RecordRepository _recordRepo = RecordRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final ReimbursementRepository _reimbRepo = ReimbursementRepository();

  double _monthTotal = 0;
  double _pendingTotal = 0;
  List<Record> _recentRecords = [];
  Map<int, Category> _categoryMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final records = await _recordRepo.getByMonth(now.year, now.month);
    final categories = await _categoryRepo.getAll();
    final pendingTotal = await _reimbRepo.getPendingTotal();
    final monthTotal = records.fold(0.0, (sum, r) => sum + r.amount);

    setState(() {
      _monthTotal = monthTotal;
      _pendingTotal = pendingTotal;
      _recentRecords = records.take(10).toList();
      _categoryMap = {for (final c in categories) c.id!: c};
      _loading = false;
    });
  }

  String _getCategoryName(int id) {
    final cat = _categoryMap[id];
    return cat?.name ?? '';
  }

  String _getCategoryIcon(int id) {
    final cat = _categoryMap[id];
    if (cat == null) return '';
    if (cat.parentId != null) {
      final parent = _categoryMap[cat.parentId];
      return parent?.icon ?? '';
    }
    return cat.icon;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人支出管理')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 统计卡片
                  Row(
                    children: [
                      StatisticCard(
                        title: '本月支出',
                        value: '¥${_monthTotal.toStringAsFixed(0)}',
                        subtitle: DateFormat('M月').format(DateTime.now()),
                        color: Colors.red,
                      ),
                      const SizedBox(width: 12),
                      StatisticCard(
                        title: '待报销',
                        value: '¥${_pendingTotal.toStringAsFixed(0)}',
                        subtitle: '${_recentRecords.length} 笔记录',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 最近支出标题
                  const Text(
                    '最近支出',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // 最近支出列表
                  if (_recentRecords.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('本月还没有记录', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ..._recentRecords.map((r) => RecordCard(
                      record: r,
                      categoryName: _getCategoryName(r.categoryId),
                      categoryIcon: _getCategoryIcon(r.categoryId),
                    )),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddRecordPage()),
          );
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/pages/home_page.dart
git commit -m "feat: add home page with monthly overview and recent records"
```

---

### 任务 11：记账流水页面（RecordsPage）

**Files:**
- Create: `lib/pages/records_page.dart`

- [ ] **Step 1: 实现记账流水页面**

`lib/pages/records_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/record_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/reimbursement_repository.dart';
import '../repositories/attachment_repository.dart';
import '../models/record.dart';
import '../models/category.dart';
import '../widgets/record_card.dart';
import 'add_record_page.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final RecordRepository _recordRepo = RecordRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final ReimbursementRepository _reimbRepo = ReimbursementRepository();
  final AttachmentRepository _attachmentRepo = AttachmentRepository();

  List<Record> _records = [];
  Map<int, Category> _categoryMap = {};
  Set<int> _reimbRecordIds = {};
  Set<int> _attachmentRecordIds = {};
  bool _loading = true;

  // 筛选状态
  int? _selectedCategoryId;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final parts = _selectedMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    var records = await _recordRepo.getByMonth(year, month);
    final categories = await _categoryRepo.getAll();
    final reimbursements = await _reimbRepo.getAll();
    final attachments = await _attachmentRepo.getAll();

    // Apply category filter
    if (_selectedCategoryId != null) {
      records = records.where((r) => r.categoryId == _selectedCategoryId).toList();
    }

    setState(() {
      _records = records;
      _categoryMap = {for (final c in categories) c.id!: c};
      _reimbRecordIds = reimbursements.map((r) => r.recordId).toSet();
      _attachmentRecordIds = attachments.map((a) => a.recordId).toSet();
      _loading = false;
    });
  }

  String _getCategoryName(int id) {
    final cat = _categoryMap[id];
    return cat?.name ?? '';
  }

  String _getCategoryIcon(int id) {
    final cat = _categoryMap[id];
    if (cat == null) return '';
    if (cat.parentId != null) {
      final parent = _categoryMap[cat.parentId];
      return parent?.icon ?? '';
    }
    return cat.icon;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记账')),
      body: Column(
        children: [
          // 月份筛选
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$_selectedMonth 共 ${_records.length} 笔',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // 月份切换
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    final parts = _selectedMonth.split('-');
                    var m = int.parse(parts[1]) - 1;
                    var y = int.parse(parts[0]);
                    if (m < 1) { m = 12; y--; }
                    _selectedMonth = '$y-${m.toString().padLeft(2, '0')}';
                    _loadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    final parts = _selectedMonth.split('-');
                    var m = int.parse(parts[1]) + 1;
                    var y = int.parse(parts[0]);
                    if (m > 12) { m = 1; y++; }
                    _selectedMonth = '$y-${m.toString().padLeft(2, '0')}';
                    _loadData();
                  },
                ),
              ],
            ),
          ),
          // 记录列表
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('暂无记录', style: TextStyle(color: Colors.grey))),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final r = _records[index];
                            return RecordCard(
                              record: r,
                              categoryName: _getCategoryName(r.categoryId),
                              categoryIcon: _getCategoryIcon(r.categoryId),
                              isReimbursing: _reimbRecordIds.contains(r.id),
                              hasAttachment: _attachmentRecordIds.contains(r.id),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddRecordPage(record: r),
                                  ),
                                );
                                _loadData();
                              },
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddRecordPage()),
          );
          _loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/pages/records_page.dart
git commit -m "feat: add records list page with month filtering"
```

---

### 任务 12：新增/编辑记账表单（AddRecordPage）

**Files:**
- Create: `lib/pages/add_record_page.dart`

- [ ] **Step 1: 实现记账表单页面**

`lib/pages/add_record_page.dart`：

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import '../models/category.dart';
import '../models/reimbursement.dart';
import '../models/attachment.dart';
import '../repositories/record_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/reimbursement_repository.dart';
import '../repositories/attachment_repository.dart';
import '../services/ocr_service.dart';
import '../widgets/category_selector.dart';
import '../widgets/payment_selector.dart';

class AddRecordPage extends StatefulWidget {
  final Record? record;
  const AddRecordPage({super.key, this.record});

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _recordRepo = RecordRepository();
  final _categoryRepo = CategoryRepository();
  final _reimbRepo = ReimbursementRepository();
  final _attachmentRepo = AttachmentRepository();
  final _ocrService = OcrService();
  final _picker = ImagePicker();

  List<Category> _parentCategories = [];
  List<Category> _childCategories = [];
  int? _selectedParentId;
  int? _selectedChildId;
  String _payment = '微信';
  String _datetime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  bool _isReimbursement = false;
  File? _screenshotFile;
  bool _saving = false;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (_isEditing) {
      _fillExistingRecord();
    }
  }

  void _fillExistingRecord() {
    final r = widget.record!;
    _amountController.text = r.amount.toStringAsFixed(2);
    _noteController.text = r.note;
    _payment = r.payment;
    _datetime = r.datetime;
    _selectedChildId = r.categoryId;
  }

  Future<void> _loadCategories() async {
    final parents = await _categoryRepo.getParents();
    final allChildren = <Category>[];
    for (final p in parents) {
      allChildren.addAll(await _categoryRepo.getChildren(p.id!));
    }
    setState(() {
      _parentCategories = parents;
      _childCategories = allChildren;
      if (_selectedChildId != null) {
        final child = allChildren.where((c) => c.id == _selectedChildId).firstOrNull;
        if (child != null) _selectedParentId = child.parentId;
      }
    });
  }

  void _onParentSelected(int parentId) {
    setState(() {
      _selectedParentId = parentId;
      _selectedChildId = null;
      // Filter children
    });
  }

  List<Category> get _filteredChildren {
    if (_selectedParentId == null) return [];
    return _childCategories.where((c) => c.parentId == _selectedParentId).toList();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) {
      setState(() => _screenshotFile = File(picked.path));
      // Auto OCR
      _processOcr(_screenshotFile!);
    }
  }

  Future<void> _processOcr(File image) async {
    try {
      final result = await _ocrService.recognize(image);
      if (result.amount != null) {
        _amountController.text = result.amount!.toStringAsFixed(2);
      }
      if (result.datetime != null) {
        _datetime = result.datetime!;
      }
      if (result.payment != null) {
        _payment = result.payment!;
      }
      if (result.merchant != null && _noteController.text.isEmpty) {
        _noteController.text = result.merchant!;
      }
      if (result.category != null) {
        // TODO: Auto-match category by keyword
      }
      setState(() {});
    } catch (e) {
      // OCR failed, ignore
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedChildId == null && _selectedParentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择类别')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final categoryId = _selectedChildId ?? _selectedParentId!;
      final record = Record(
        id: widget.record?.id,
        amount: double.parse(_amountController.text),
        categoryId: categoryId,
        note: _noteController.text,
        payment: _payment,
        datetime: _datetime,
      );

      int recordId;
      if (_isEditing) {
        await _recordRepo.update(record);
        recordId = widget.record!.id!;
      } else {
        recordId = await _recordRepo.insert(record);
      }

      // 保存报销标记
      if (_isReimbursement) {
        await _reimbRepo.insert(Reimbursement(recordId: recordId));
      }

      // 保存截图
      if (_screenshotFile != null) {
        await _attachmentRepo.insert(Attachment(
          recordId: recordId,
          filePath: _screenshotFile!.path,
        ));
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑记录' : '记一笔'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 金额
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              validator: (v) {
                if (v == null || v.isEmpty) return '请输入金额';
                if (double.tryParse(v) == null) return '请输入有效数字';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 类别
            const Text('类别', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CategorySelector(
              parentCategories: _parentCategories,
              childCategories: _filteredChildren,
              selectedParentId: _selectedParentId,
              selectedChildId: _selectedChildId,
              onParentSelected: _onParentSelected,
              onChildSelected: (id) => setState(() => _selectedChildId = id),
            ),
            const SizedBox(height: 20),

            // 支付方式
            const Text('支付方式', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            PaymentSelector(
              selectedPayment: _payment,
              onChanged: (v) => setState(() => _payment = v),
            ),
            const SizedBox(height: 20),

            // 时间
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(_datetime),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    _datetime = DateFormat('yyyy-MM-dd HH:mm:ss').format(
                      DateTime(date.year, date.month, date.day, time.hour, time.minute),
                    );
                    setState(() {});
                  }
                }
              },
            ),
            const SizedBox(height: 12),

            // 备注
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // 截图 + 报销 行
            Row(
              children: [
                // 添加截图
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showImagePickerOptions(),
                    icon: Icon(
                      _screenshotFile != null ? Icons.check_circle : Icons.camera_alt,
                      color: _screenshotFile != null ? Colors.green : null,
                    ),
                    label: Text(_screenshotFile != null ? '已添加截图' : '添加截图'),
                  ),
                ),
                const SizedBox(width: 12),
                // 待报销开关
                Expanded(
                  child: SwitchListTile(
                    title: const Text('待报销'),
                    value: _isReimbursement,
                    onChanged: (v) => setState(() => _isReimbursement = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 保存按钮
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('保存', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_screenshotFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('移除截图', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _screenshotFile = null);
                },
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/pages/add_record_page.dart
git commit -m "feat: add record form with OCR, image picker, and reimbursement toggle"
```

---

### 任务 13：报表页面（ReportPage）

**Files:**
- Create: `lib/pages/report_page.dart`

- [ ] **Step 1: 实现报表页**

`lib/pages/report_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import '../models/category.dart';
import '../repositories/record_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/reimbursement_repository.dart';

class _CategoryTotal {
  final Category category;
  final double total;
  _CategoryTotal({required this.category, required this.total});
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final RecordRepository _recordRepo = RecordRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final ReimbursementRepository _reimbRepo = ReimbursementRepository();

  late DateTime _currentMonth;
  double _monthTotal = 0;
  int _recordCount = 0;
  double _pendingTotal = 0;
  List<_CategoryTotal> _categoryTotals = [];
  Map<String, double> _paymentTotals = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    final year = _currentMonth.year;
    final month = _currentMonth.month;

    final records = await _recordRepo.getByMonth(year, month);
    final categories = await _categoryRepo.getAll();
    final categoryMap = {for (final c in categories) c.id!: c};
    final pendingTotal = await _reimbRepo.getPendingTotal();

    // Calculate category totals (group by parent category)
    final catTotals = <int, double>{};
    final payTotals = <String, double>{};

    for (final record in records) {
      final cat = categoryMap[record.categoryId];
      final parentId = cat?.parentId ?? record.categoryId;
      catTotals[parentId] = (catTotals[parentId] ?? 0) + record.amount;
      payTotals[record.payment] = (payTotals[record.payment] ?? 0) + record.amount;
    }

    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _monthTotal = records.fold(0.0, (sum, r) => sum + r.amount);
      _recordCount = records.length;
      _pendingTotal = pendingTotal;
      _categoryTotals = sortedCats.map((e) {
        final cat = categoryMap[e.key]!;
        return _CategoryTotal(category: cat, total: e.value);
      }).toList();
      _paymentTotals = payTotals;
      _loading = false;
    });
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _loading = true;
    });
    _loadData();
  }

  void _nextMonth() {
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1);
    if (!next.isAfter(DateTime.now())) {
      setState(() {
        _currentMonth = next;
        _loading = true;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('yyyy年M月').format(_currentMonth);

    return Scaffold(
      appBar: AppBar(title: const Text('报表')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 月份切换
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _previousMonth,
                      ),
                      Text(
                        monthLabel,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 月度汇总
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('本月总支出', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '¥${_monthTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _summaryItem('笔数', '$_recordCount'),
                            const SizedBox(width: 32),
                            _summaryItem('日均', _recordCount > 0
                              ? '¥${(_monthTotal / _recordCount).toStringAsFixed(0)}'
                              : '¥0'),
                            const SizedBox(width: 32),
                            _summaryItem('待报销', '¥${_pendingTotal.toStringAsFixed(0)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 分类排行
                  const Text('分类支出排行', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._categoryTotals.map((ct) {
                    final ratio = _monthTotal > 0 ? ct.total / _monthTotal : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(ct.category.icon),
                              const SizedBox(width: 4),
                              Text(ct.category.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              const Spacer(),
                              Text('¥${ct.total.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // 支付方式占比
                  const Text('支付方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _paymentTotals.entries.map((e) {
                      final ratio = _monthTotal > 0 ? e.value / _monthTotal : 0.0;
                      return Chip(
                        label: Text('${e.key} ${(ratio * 100).toStringAsFixed(0)}%'),
                        backgroundColor: Colors.green.shade50,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/pages/report_page.dart
git commit -m "feat: add report page with monthly statistics and category breakdown"
```

---

### 任务 14：报销管理 + 设置页面

**Files:**
- Create: `lib/pages/reimbursement_list_page.dart`
- Create: `lib/pages/settings_page.dart`

- [ ] **Step 1: 实现报销列��页**

`lib/pages/reimbursement_list_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import '../models/category.dart';
import '../repositories/record_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/reimbursement_repository.dart';

class ReimbursementListPage extends StatefulWidget {
  const ReimbursementListPage({super.key});

  @override
  State<ReimbursementListPage> createState() => _ReimbursementListPageState();
}

class _ReimbursementListPageState extends State<ReimbursementListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('报销管理')),
      body: const Center(child: Text('报销列表')),
    );
  }
}
```

- [ ] **Step 2: 实现设置页面**

`lib/pages/settings_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // 需要额外添加依赖
import '../models/category.dart';
import '../repositories/category_repository.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final CategoryRepository _categoryRepo = CategoryRepository();
  final ExportService _exportService = ExportService();
  final ImportService _importService = ImportService();
  List<Category> _categories = [];
  bool _includeImages = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _categoryRepo.getAll();
    setState(() {
      _categories = cats;
      _loading = false;
    });
  }

  Future<void> _export() async {
    try {
      final path = await _exportService.export(includeImages: _includeImages);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出成功: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result != null && result.files.single.path != null) {
        final importResult = await _importService.importFromZip(result.files.single.path!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(importResult.message)),
          );
          _loadCategories();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  Future<void> _addCategory() async {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新增类别'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
            TextField(controller: iconCtrl, decoration: const InputDecoration(labelText: '图标 (emoji)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );

    if (result == true && nameCtrl.text.isNotEmpty) {
      await _categoryRepo.insert(Category(
        name: nameCtrl.text,
        icon: iconCtrl.text.isNotEmpty ? iconCtrl.text : '📦',
      ));
      _loadCategories();
    }
  }

  Future<void> _deleteCategory(Category cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${cat.name}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && cat.id != null) {
      await _categoryRepo.delete(cat.id!);
      _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 分类管理
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('分类管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: _addCategory,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 表头
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(width: 36, child: Text('图标', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(child: Text('名称', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              SizedBox(width: 60, child: Text('类型', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              SizedBox(width: 60, child: Text('操作', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                        ),
                        // 分类列表
                        ..._categories.map((cat) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(width: 36, child: Text(cat.icon, style: const TextStyle(fontSize: 18))),
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontWeight: cat.isParent ? FontWeight.bold : FontWeight.normal,
                                    fontSize: cat.isParent ? 14 : 13,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  cat.isParent ? '一级' : '子类别',
                                  style: TextStyle(fontSize: 12, color: cat.isParent ? Colors.green : Colors.grey),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16),
                                      onPressed: () {}, // TODO: edit
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                      onPressed: () => _deleteCategory(cat),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 导出
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('导出数据', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          title: const Text('包含截图（导出为 ZIP）'),
                          value: _includeImages,
                          onChanged: (v) => setState(() => _includeImages = v!),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _export,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('导出'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 导入
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('导入数据', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('选择之前导出的 ZIP 文件恢复数据',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _import,
                            icon: const Icon(Icons.file_download),
                            label: const Text('选择文件导入'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/pages/reimbursement_list_page.dart lib/pages/settings_page.dart
git commit -m "feat: add settings page with category management and export/import"
```

---

## 阶段五：集成与完善

### 任务 15：报销列表页完整实现

**Files:**
- Modify: `lib/pages/reimbursement_list_page.dart`

- [ ] **Step 1: 完整实现报销管理页面**

替换 `lib/pages/reimbursement_list_page.dart` 内容：

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import '../models/category.dart';
import '../repositories/record_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/reimbursement_repository.dart';

class _ReimbItem {
  final int reimbId;
  final int recordId;
  final double amount;
  final String note;
  final String datetime;
  final String status;
  final String categoryName;
  final String categoryIcon;
  _ReimbItem({
    required this.reimbId,
    required this.recordId,
    required this.amount,
    required this.note,
    required this.datetime,
    required this.status,
    required this.categoryName,
    required this.categoryIcon,
  });
}

class ReimbursementListPage extends StatefulWidget {
  const ReimbursementListPage({super.key});

  @override
  State<ReimbursementListPage> createState() => _ReimbursementListPageState();
}

class _ReimbursementListPageState extends State<ReimbursementListPage>
    with DefaultTabController {
  @override
  int get tabLength => 2;

  final RecordRepository _recordRepo = RecordRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final ReimbursementRepository _reimbRepo = ReimbursementRepository();

  List<_ReimbItem> _pendingItems = [];
  List<_ReimbItem> _doneItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final reimbursements = await _reimbRepo.getAll();
    final categories = await _categoryRepo.getAll();
    final categoryMap = {for (final c in categories) c.id!: c};

    final pending = <_ReimbItem>[];
    final done = <_ReimbItem>[];

    for (final reimb in reimbursements) {
      final record = await _recordRepo.getById(reimb.recordId);
      if (record == null) continue;
      final cat = categoryMap[record.categoryId];
      final parentCat = cat?.parentId != null ? categoryMap[cat!.parentId!] : cat;

      final item = _ReimbItem(
        reimbId: reimb.id!,
        recordId: record.id!,
        amount: record.amount,
        note: record.note,
        datetime: record.datetime,
        status: reimb.status,
        categoryName: parentCat?.name ?? '',
        categoryIcon: parentCat?.icon ?? '',
      );

      if (reimb.isPending) {
        pending.add(item);
      } else {
        done.add(item);
      }
    }

    setState(() {
      _pendingItems = pending;
      _doneItems = done;
      _loading = false;
    });
  }

  Future<void> _settle(_ReimbItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认核销'),
        content: Text('确认已收到 ¥${item.amount.toStringAsFixed(2)} 报销款？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认核销', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _reimbRepo.markAsDone(item.reimbId, today);
      _loadData();
    }
  }

  Widget _buildList(List<_ReimbItem> items, {bool showSettle = false}) {
    if (items.isEmpty) {
      return const Center(child: Text('暂无记录', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade50,
              child: Text(item.categoryIcon, style: const TextStyle(fontSize: 20)),
            ),
            title: Text('${item.categoryName} - ¥${item.amount.toStringAsFixed(2)}'),
            subtitle: Text(item.note.isNotEmpty ? item.note : item.datetime),
            trailing: showSettle
                ? ElevatedButton(
                    onPressed: () => _settle(item),
                    child: const Text('核销'),
                  )
                : const Icon(Icons.check_circle, color: Colors.green),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('报销管理'),
        bottom: TabBar(
          tabs: [
            Tab(text: '待报销 (${_pendingItems.length})'),
            Tab(text: '已报销 (${_doneItems.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                _buildList(_pendingItems, showSettle: true),
                _buildList(_doneItems),
              ],
            ),
    );
  }
}
```

注意：该页面使用 TabBar，需要在 `app.dart` 集成时确保 `ReimbursementListPage` 可以从设置页面或其他入口导航进入。

- [ ] **Step 2: 提交**

```bash
git add lib/pages/reimbursement_list_page.dart
git commit -m "feat: complete reimbursement list with settle functionality"
```

---

### 任务 16：Android 原生截图监听实现

**Files:**
- Create: `android/app/src/main/java/com/yingfeng/expense/ScreenshotPlugin.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 注册截图监听的 Android 原生代码**

（需在 Android 端实现 ContentObserver 监听媒体库截图）
- [ ] **Step 2: 申请相关权限（READ_EXTERNAL_STORAGE）**
- [ ] **Step 3: 提交**

---

### 任务 17：整体集成测试与 Bug 修复

**Files:** 所有文件

- [ ] **Step 1: 构建 APK 验证**

```bash
flutter build apk --debug
```

- [ ] **Step 2: 走查所有页面交互，修复发现的问题**
- [ ] **Step 3: 最终提交**

```bash
git add .
git commit -m "chore: integrate all features and fix bugs"
```

---

## 依赖关系图

```
任务1 (脚手架) ──→ 任务2 (Models) ──→ 任务3 (数据库) ──→ 任务4 (Repositories)
                                                              │
任务5 (OCR) ──→ 任务6 (截图监听) ───────────────────────────┤
                                                              │
                                                              ├──→ 任务8 (Widgets)
                                                              │
任务7 (导出导入) ──────────────────────────────────────────────┤
                                                              │
                                             任务9 (AppShell) ─┤
                                             任务10 (首页) ─────┤
                                             任务11 (记账页) ───┤
                                             任务12 (表单页) ───┤
                                             任务13 (报表页) ───┤
                                             任务14 (设置页) ───┤
                                                              │
                                             任务15 (报销页) ───┘
                                             任务16 (截图原生)
```

**可并行执行的组：**

| 批次 | 可并行任务 | 说明 |
|------|-----------|------|
| 批次1 | 任务1 | 先搭架子 |
| 批次2 | 任务2 + 任务5 + 任务6 + 任务7 | 数据模型 + 各服务可并行 |
| 批次3 | 任务3 + 任务4 | 数据库 + Repository（依赖任务2） |
| 批次4 | 任务8 ~ 任务14 | 所有 UI 页 + 组件可并行（依赖任务4） |
| 批次5 | 任务15 + 任务16 + 任务17 | 集成 + 完善 |
