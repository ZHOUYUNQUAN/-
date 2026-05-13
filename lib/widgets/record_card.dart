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
