import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
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

    final categoryMap = <int, Category>{};
    for (final c in categories) {
      if (c.id != null) categoryMap[c.id!] = c;
    }
    final reimbMap = <int, Reimbursement>{};
    for (final r in reimbursements) {
      reimbMap[r.recordId] = r;
    }
    final attachmentMap = <int, List<Attachment>>{};
    for (final a in attachments) {
      attachmentMap.putIfAbsent(a.recordId, () => []).add(a);
    }

    final header = <String>[
      'ID', '金额', '类别', '子类别', '备注', '支付方式', '时间', '报销状态', '截图数'
    ];
    final rows = <List<String>>[header];

    for (final record in records) {
      final cat = categoryMap[record.categoryId];
      final parentCat =
          cat?.parentId != null ? categoryMap[cat!.parentId!] : null;
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
        reimb?.status == 'done'
            ? '已报销'
            : (reimb != null ? '待报销' : ''),
        atts.length.toString(),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dir = await getApplicationDocumentsDirectory();

    if (includeImages && attachments.isNotEmpty) {
      final archive = Archive();
      archive.addFile(ArchiveFile(
          'expenses.csv', csvData.length, utf8.encode(csvData)));

      final processedPaths = <String>{};
      for (final att in attachments) {
        final file = File(att.filePath);
        if (await file.exists() && !processedPaths.contains(att.filePath)) {
          processedPaths.add(att.filePath);
          final bytes = await file.readAsBytes();
          final fileName =
              'images/${att.recordId}_${att.id}${_getExtension(att.filePath)}';
          archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
        }
      }

      final zipBytes = ZipEncoder().encode(archive);
      final zipFile = File('${dir.path}/expenses_$timestamp.zip');
      await zipFile.writeAsBytes(zipBytes!);
      return zipFile.path;
    } else {
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
