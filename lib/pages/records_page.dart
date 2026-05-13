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

    final records = await _recordRepo.getByMonth(year, month);
    final categories = await _categoryRepo.getAll();
    final reimbursements = await _reimbRepo.getAll();
    final attachments = await _attachmentRepo.getAll();

    setState(() {
      _records = records;
      _categoryMap = {
        for (final c in categories) if (c.id != null) c.id!: c
      };
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

  void _previousMonth() {
    final parts = _selectedMonth.split('-');
    var m = int.parse(parts[1]) - 1;
    var y = int.parse(parts[0]);
    if (m < 1) {
      m = 12;
      y--;
    }
    _selectedMonth = '$y-${m.toString().padLeft(2, '0')}';
    _loading = true;
    _loadData();
  }

  void _nextMonth() {
    final parts = _selectedMonth.split('-');
    var m = int.parse(parts[1]) + 1;
    var y = int.parse(parts[0]);
    if (m > 12) {
      m = 1;
      y++;
    }
    _selectedMonth = '$y-${m.toString().padLeft(2, '0')}';
    _loading = true;
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记账')),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$_selectedMonth 共 ${_records.length} 笔',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 100),
                          Center(
                              child: Text('暂无记录',
                                  style: TextStyle(color: Colors.grey))),
                        ])
                      : ListView.builder(
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final r = _records[index];
                            return RecordCard(
                              record: r,
                              categoryName:
                                  _getCategoryName(r.categoryId),
                              categoryIcon:
                                  _getCategoryIcon(r.categoryId),
                              isReimbursing:
                                  _reimbRecordIds.contains(r.id),
                              hasAttachment:
                                  _attachmentRecordIds.contains(r.id),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AddRecordPage(record: r),
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
