class Reimbursement {
  final int? id;
  final int recordId;
  final String status;
  final String? reimbursedDate;
  final String note;

  Reimbursement({
    this.id,
    required this.recordId,
    this.status = 'pending',
    this.reimbursedDate,
    this.note = '',
  });

  bool get isPending => status == 'pending';
  bool get isDone => status == 'done';

  Map<String, dynamic> toMap() => {
        'id': id,
        'record_id': recordId,
        'status': status,
        'reimbursed_date': reimbursedDate,
        'note': note,
      };

  factory Reimbursement.fromMap(Map<String, dynamic> map) => Reimbursement(
        id: map['id'] as int?,
        recordId: map['record_id'] as int,
        status: map['status'] as String? ?? 'pending',
        reimbursedDate: map['reimbursed_date'] as String?,
        note: map['note'] as String? ?? '',
      );
}
