import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    final categoryMap = <int, Category>{};
    for (final c in categories) {
      if (c.id != null) categoryMap[c.id!] = c;
    }
    final pendingTotal = await _reimbRepo.getPendingTotal();

    final catTotals = <int, double>{};
    final payTotals = <String, double>{};

    for (final record in records) {
      final cat = categoryMap[record.categoryId];
      final parentId = cat?.parentId ?? record.categoryId;
      catTotals[parentId] = (catTotals[parentId] ?? 0) + record.amount;
      payTotals[record.payment] =
          (payTotals[record.payment] ?? 0) + record.amount;
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
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month - 1);
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _previousMonth,
                      ),
                      Text(
                        monthLabel,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('本月总支出',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '¥${_monthTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _summaryItem('笔数', '$_recordCount'),
                            const SizedBox(width: 32),
                            _summaryItem(
                                '日均',
                                _recordCount > 0
                                    ? '¥${(_monthTotal / _recordCount).toStringAsFixed(0)}'
                                    : '¥0'),
                            const SizedBox(width: 32),
                            _summaryItem('待报销',
                                '¥${_pendingTotal.toStringAsFixed(0)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('分类支出排行',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._categoryTotals.map((ct) {
                    final ratio = _monthTotal > 0
                        ? ct.total / _monthTotal
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(ct.category.icon),
                              const SizedBox(width: 4),
                              Text(ct.category.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              const Spacer(),
                              Text('¥${ct.total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
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
                  const Text('支付方式',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _paymentTotals.entries.map((e) {
                      final ratio = _monthTotal > 0
                          ? e.value / _monthTotal
                          : 0.0;
                      return Chip(
                        label: Text(
                            '${e.key} ${(ratio * 100).toStringAsFixed(0)}%'),
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
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
