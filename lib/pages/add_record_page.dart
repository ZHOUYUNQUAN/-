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
  final File? initialScreenshot;

  const AddRecordPage({super.key, this.record, this.initialScreenshot});

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
  List<Category> _allChildren = [];
  int? _selectedParentId;
  int? _selectedChildId;
  String _payment = '微信';
  String _datetime =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  bool _isReimbursement = false;
  File? _screenshotFile;
  bool _saving = false;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (_isEditing) _fillExistingRecord();
    if (widget.initialScreenshot != null) {
      _screenshotFile = widget.initialScreenshot;
      _processOcr(_screenshotFile!);
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
    final children = <Category>[];
    for (final p in parents) {
      children.addAll(await _categoryRepo.getChildren(p.id!));
    }
    setState(() {
      _parentCategories = parents;
      _allChildren = children;
      if (_selectedChildId != null) {
        final child =
            children.where((c) => c.id == _selectedChildId).firstOrNull;
        if (child != null) _selectedParentId = child.parentId;
      }
    });
  }

  void _onParentSelected(int parentId) {
    setState(() {
      _selectedParentId = parentId;
      _selectedChildId = null;
    });
  }

  List<Category> get _filteredChildren {
    if (_selectedParentId == null) return [];
    return _allChildren
        .where((c) => c.parentId == _selectedParentId)
        .toList();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) {
      setState(() => _screenshotFile = File(picked.path));
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
        for (final p in _parentCategories) {
          if (p.name == result.category) {
            _selectedParentId = p.id;
            break;
          }
        }
      }
      setState(() {});
    } catch (e) {
      // Tesseract OCR may fail if traineddata is missing
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

      if (_isReimbursement) {
        final existing =
            await _reimbRepo.getByRecordId(recordId);
        if (existing == null) {
          await _reimbRepo.insert(
              Reimbursement(recordId: recordId));
        }
      }

      if (_screenshotFile != null) {
        await _attachmentRepo.insert(Attachment(
          recordId: recordId,
          filePath: _screenshotFile!.path,
        ));
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
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
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold),
              validator: (v) {
                if (v == null || v.isEmpty) return '请输入金额';
                if (double.tryParse(v) == null) return '请输入有效数字';
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text('类别',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CategorySelector(
              parentCategories: _parentCategories,
              childCategories: _filteredChildren,
              selectedParentId: _selectedParentId,
              selectedChildId: _selectedChildId,
              onParentSelected: _onParentSelected,
              onChildSelected: (id) =>
                  setState(() => _selectedChildId = id),
            ),
            const SizedBox(height: 20),
            const Text('支付方式',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            PaymentSelector(
              selectedPayment: _payment,
              onChanged: (v) => setState(() => _payment = v),
            ),
            const SizedBox(height: 20),
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
                if (date != null && context.mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    _datetime =
                        DateFormat('yyyy-MM-dd HH:mm:ss').format(
                      DateTime(date.year, date.month, date.day,
                          time.hour, time.minute),
                    );
                    setState(() {});
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showImagePickerOptions,
                    icon: Icon(
                      _screenshotFile != null
                          ? Icons.check_circle
                          : Icons.camera_alt,
                      color: _screenshotFile != null
                          ? Colors.green
                          : null,
                    ),
                    label: Text(_screenshotFile != null
                        ? '已添加截图'
                        : '添加截图'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile(
                    title: const Text('待报销'),
                    value: _isReimbursement,
                    onChanged: (v) =>
                        setState(() => _isReimbursement = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('保存',
                        style: TextStyle(fontSize: 16)),
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
                leading:
                    const Icon(Icons.delete, color: Colors.red),
                title: const Text('移除截图',
                    style: TextStyle(color: Colors.red)),
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
