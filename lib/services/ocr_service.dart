// OCR service placeholder - to be implemented with DeepSeek API later
class OcrResult {
  final double? amount;
  final String? merchant;
  final String? datetime;
  final String? category;
  final String? payment;

  OcrResult({
    this.amount,
    this.merchant,
    this.datetime,
    this.category,
    this.payment,
  });

  bool get hasAny =>
      amount != null ||
      merchant != null ||
      datetime != null ||
      category != null ||
      payment != null;
}
