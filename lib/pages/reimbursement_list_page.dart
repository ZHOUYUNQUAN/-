import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  State<ReimbursementListPage> createState() =>
      _ReimbursementListPageState();
}

class _ReimbursementListPageState extends State<ReimbursementListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final RecordRepository _recordRepo = RecordRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final ReimbursementRepository _reimbRepo = ReimbursementRepository();

  List<_ReimbItem> _pendingItems = [];
  List<_ReimbItem> _doneItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final reimbursements = await _reimbRepo.getAll();
    final categories = await _categoryRepo.getAll();
    final categoryMap = <int, Category>{};
    for (final c in categories) {
      if (c.id != null) categoryMap[c.id!] = c;
    }

    final pending = <_ReimbItem>[];
    final done = <_ReimbItem>[];

    for (final reimb in reimbursements) {
      final record = await _recordRepo.getById(reimb.recordId);
      if (record == null) continue;
      final cat = categoryMap[record.categoryId];
      final parentCat =
          cat?.parentId != null ? categoryMap[cat!.parentId!] : cat;

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
        content:
            Text('确认已收到 ¥${item.amount.toStringAsFixed(2)} 报销款？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认核销',
                style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final today =
          DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _reimbRepo.markAsDone(item.reimbId, today);
      _loadData();
    }
  }

  Widget _buildList(List<_ReimbItem> items,
      {bool showSettle = false}) {
    if (items.isEmpty) {
      return const Center(
          child: Text('暂无记录',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Card(
          margin:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade50,
              child: Text(item.categoryIcon,
                  style: const TextStyle(fontSize: 20)),
            ),
            title: Text(
                '${item.categoryName} - ¥${item.amount.toStringAsFixed(2)}'),
            subtitle: Text(
                item.note.isNotEmpty ? item.note : item.datetime),
            trailing: showSettle
                ? ElevatedButton(
                    onPressed: () => _settle(item),
                    child: const Text('核销'),
                  )
                : const Icon(Icons.check_circle,
                    color: Colors.green),
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
          controller: _tabController,
          tabs: [
            Tab(text: '待报销 (${_pendingItems.length})'),
            Tab(text: '已报销 (${_doneItems.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_pendingItems, showSettle: true),
                _buildList(_doneItems),
              ],
            ),
    );
  }
}
