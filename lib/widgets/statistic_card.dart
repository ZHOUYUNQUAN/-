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
          color: (color ?? Colors.green).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
