import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import 'reimbursement_list_page.dart';

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
    try {
      final cats = await _categoryRepo.getAll();
      setState(() {
        _categories = cats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
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
        final importResult =
            await _importService.importFromZip(result.files.single.path!);
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
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名称')),
            TextField(
                controller: iconCtrl,
                decoration: const InputDecoration(labelText: '图标 (emoji)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存')),
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

  Future<void> _editCategory(Category cat) async {
    final nameCtrl = TextEditingController(text: cat.name);
    final iconCtrl = TextEditingController(text: cat.icon);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('编辑类别'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名称')),
            TextField(
                controller: iconCtrl,
                decoration: const InputDecoration(labelText: '图标 (emoji)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存')),
        ],
      ),
    );

    if (result == true && nameCtrl.text.isNotEmpty && cat.id != null) {
      await _categoryRepo.update(cat.copyWith(
        name: nameCtrl.text,
        icon: iconCtrl.text.isNotEmpty ? iconCtrl.text : cat.icon,
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('删除', style: TextStyle(color: Colors.red))),
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
                // Reimbursement management
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: const Text('报销管理'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const ReimbursementListPage()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Category management
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('分类管理',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: Colors.green),
                              onPressed: _addCategory,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                  width: 36,
                                  child: Text('图标',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                              Expanded(
                                  child: Text('名称',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                              SizedBox(
                                  width: 60,
                                  child: Text('类型',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                              SizedBox(
                                  width: 60,
                                  child: Text('操作',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                            ],
                          ),
                        ),
                        ..._categories.map((cat) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                      width: 36,
                                      child: Text(cat.icon,
                                          style: const TextStyle(
                                              fontSize: 18))),
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      style: TextStyle(
                                        fontWeight: cat.isParent
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize:
                                            cat.isParent ? 14 : 13,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      cat.isParent ? '一级' : '子类别',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cat.isParent
                                              ? Colors.green
                                              : Colors.grey),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              size: 16),
                                          onPressed: () =>
                                              _editCategory(cat),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete,
                                              size: 16,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _deleteCategory(cat),
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
                // Export
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('导出数据',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          title:
                              const Text('包含截图（导出为 ZIP）'),
                          value: _includeImages,
                          onChanged: (v) =>
                              setState(() => _includeImages = v!),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _export,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('导出'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Import
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('导入数据',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                            '选择之前导出的 ZIP 文件恢复数据',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _import,
                            icon: const Icon(Icons.file_download),
                            label: const Text('选择文件导入'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange),
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
