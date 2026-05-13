import 'package:flutter/material.dart';

class PaymentSelector extends StatelessWidget {
  final String selectedPayment;
  final ValueChanged<String> onChanged;

  static const payments = ['微信', '支付宝', '现金', '银行卡'];

  const PaymentSelector({
    super.key,
    required this.selectedPayment,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: payments.map((payment) {
        final isSelected = payment == selectedPayment;
        return GestureDetector(
          onTap: () => onChanged(payment),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_iconFor(payment)} $payment',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.green : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _iconFor(String payment) {
    switch (payment) {
      case '微信':
      case '支付宝':
      case '银行卡':
        return '💳';
      case '现金':
        return '💵';
    }
    return '💳';
  }
}
