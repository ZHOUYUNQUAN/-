class Attachment {
  final int? id;
  final int recordId;
  final String filePath;
  final String createdAt;

  Attachment({
    this.id,
    required this.recordId,
    required this.filePath,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'record_id': recordId,
        'file_path': filePath,
        'created_at': createdAt,
      };

  factory Attachment.fromMap(Map<String, dynamic> map) => Attachment(
        id: map['id'] as int?,
        recordId: map['record_id'] as int,
        filePath: map['file_path'] as String,
        createdAt: map['created_at'] as String?,
      );
}
