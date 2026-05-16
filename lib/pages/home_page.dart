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
    try {
      final now = DateTime.now();
      final records = await _recordRepo.getByMonth(now.year, now.month);
      final categories = await _categoryRepo.getAll();
      final pendingTotal = await _reimbRepo.getPendingTotal();
      final monthTotal = records.fold(0.0, (sum, r) => sum + r.amount);

      setState(() {
        _monthTotal = monthTotal;
        _pendingTotal = pendingTotal;
        _recentRecords = records.take(10).toList();
        _categoryMap = {for (final c in categories) if (c.id != null) c.id!: c};
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
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
                  const Text(
                    '最近支出',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_recentRecords.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('本月还没有记录',
                            style: TextStyle(color: Colors.grey)),
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
