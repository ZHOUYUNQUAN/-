import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../repositories/record_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/reimbursement_repository.dart';
import '../models/record.dart';
import '../models/reimbursement.dart';

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
  final CategoryRepository _categoryRepo = CategoryRepository();
  final ReimbursementRepository _reimbRepo = ReimbursementRepository();

  Future<ImportResult> importFromZip(String zipPath) async {
    final file = File(zipPath);
    if (!await file.exists()) {
      return ImportResult(
          recordsImported: 0, imagesImported: 0, message: '文件不存在');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${dir.path}/imported_images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }

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
      return ImportResult(
          recordsImported: 0,
          imagesImported: 0,
          message: 'ZIP 中未找到 expenses.csv');
    }

    final csvContent = utf8.decode(csvFile.content);
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.isEmpty) {
      return ImportResult(
          recordsImported: 0, imagesImported: 0, message: 'CSV 为空');
    }

    // Build category name->id mapping
    final categories = await _categoryRepo.getAll();
    final nameToId = <String, int>{};
    for (final c in categories) {
      if (c.id != null) nameToId[c.name] = c.id!;
    }

    int recordCount = 0;
    int imageCount = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 7) continue;

      try {
        final categoryId = _resolveCategoryId(
            nameToId, row[2] as String, row[3] as String);
        final recordId = await _recordRepo.insert(Record(
          amount: (row[1] as num).toDouble(),
          categoryId: categoryId,
          note: row[4] as String? ?? '',
          payment: row[5] as String? ?? '微信',
          datetime: row[6] as String,
        ));

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

    for (final imgFile in imageFiles) {
      final targetPath =
          '${imageDir.path}/${imgFile.name.replaceFirst('images/', '')}';
      await File(targetPath).writeAsBytes(imgFile.content);
      imageCount++;
    }

    return ImportResult(
      recordsImported: recordCount,
      imagesImported: imageCount,
      message: '成功导入 $recordCount 条记录，$imageCount 张图片',
    );
  }

  int _resolveCategoryId(
      Map<String, int> nameToId, String parentName, String childName) {
    if (childName.isNotEmpty && nameToId.containsKey(childName)) {
      return nameToId[childName]!;
    }
    if (parentName.isNotEmpty && nameToId.containsKey(parentName)) {
      return nameToId[parentName]!;
    }
    return nameToId.values.first;
  }
}
