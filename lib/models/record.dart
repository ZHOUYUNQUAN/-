class Record {
  final int? id;
  final double amount;
  final int categoryId;
  final String note;
  final String payment;
  final String datetime;
  final String createdAt;

  Record({
    this.id,
    required this.amount,
    required this.categoryId,
    this.note = '',
    this.payment = '微信',
    required this.datetime,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'category_id': categoryId,
        'note': note,
        'payment': payment,
        'datetime': datetime,
        'created_at': createdAt,
      };

  factory Record.fromMap(Map<String, dynamic> map) => Record(
        id: map['id'] as int?,
        amount: (map['amount'] as num).toDouble(),
        categoryId: map['category_id'] as int,
        note: map['note'] as String? ?? '',
        payment: map['payment'] as String? ?? '微信',
        datetime: map['datetime'] as String,
        createdAt: map['created_at'] as String?,
      );

  Record copyWith({
    int? id,
    double? amount,
    int? categoryId,
    String? note,
    String? payment,
    String? datetime,
    String? createdAt,
  }) =>
      Record(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        note: note ?? this.note,
        payment: payment ?? this.payment,
        datetime: datetime ?? this.datetime,
        createdAt: createdAt ?? this.createdAt,
      );
}
