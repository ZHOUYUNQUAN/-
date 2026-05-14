import 'dart:io';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

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

class OcrService {
  static bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
  }

  Future<OcrResult> recognize(File imageFile) async {
    await ensureInitialized();

    final fullText = await TesseractOcr.extractText(
      imageFile.path,
      config: const OCRConfig(
        language: 'chi_sim',
        engine: OCREngine.tesseract,
      ),
    );

    final lines = fullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final amount = _extractAmount(fullText);
    final payment = _extractPayment(fullText);
    final datetime = _extractDatetime(fullText);
    final merchant = _extractMerchant(lines, payment);
    final category = _extractCategory(fullText);

    return OcrResult(
      amount: amount,
      merchant: merchant ?? _extractFirstLine(lines),
      datetime: datetime,
      category: category,
      payment: payment,
    );
  }

  double? _extractAmount(String text) {
    // ¥/￥ prefix patterns
    final patterns = [
      RegExp(r'[实付|应付|合计|消费|金额|付款|¥|￥]\s*(\d+\.?\d*)'),
      RegExp(r'[¥￥](\d+\.\d{2})'),
      RegExp(r'([-]?\d+\.\d{2})'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(text);
      if (m != null) {
        final val = double.tryParse(m.group(1)!);
        if (val != null && val > 0 && val < 100000) return val;
      }
    }
    return null;
  }

  String? _extractPayment(String text) {
    if (text.contains('微信') || text.contains('WeChat')) return '微信';
    if (text.contains('支付宝') || text.contains('Alipay')) return '支付宝';
    if (text.contains('银行卡') || text.contains('银联') || text.contains('刷卡')) return '银行卡';
    return null;
  }

  String? _extractDatetime(String text) {
    final re = RegExp(r'(\d{4}[-/年]\d{1,2}[-/月]\d{1,2})[日]?\s*(\d{1,2}:\d{2})');
    final m = re.firstMatch(text);
    if (m != null) {
      final date = m.group(1)!
          .replaceAll('年', '-')
          .replaceAll('月', '-')
          .replaceAll('/', '-');
      return '$date ${m.group(2)}:00';
    }
    return null;
  }

  String? _extractMerchant(List<String> lines, String? payment) {
    for (final line in lines) {
      if (line.length >= 2 &&
          line.length <= 25 &&
          !RegExp(r'[¥￥\d:：]').hasMatch(line) &&
          line != payment &&
          !line.contains('支付') &&
          !line.contains('扫码') &&
          !line.contains('收款') &&
          !line.contains('微信') &&
          !line.contains('支付宝')) {
        return line;
      }
    }
    return null;
  }

  String? _extractFirstLine(List<String> lines) {
    if (lines.isNotEmpty && lines.first.length <= 25) {
      return lines.first;
    }
    return null;
  }

  String? _extractCategory(String text) {
    const keywords = {
      '餐饮': ['餐', '饭', '吃', '食堂', '外卖', '午餐', '早餐', '晚餐', '美食', 'KFC', '麦当劳', '星巴克', '咖啡', '奶茶', '面', '粉', '饼'],
      '交通': ['打车', '滴滴', '公交', '地铁', '加油', '停车', '高铁', '机票', '出租车', '行程'],
      '医疗': ['医院', '药店', '医药', '诊所', '体检', '药'],
      '居住': ['房租', '水电', '物业', '燃气', '暖气'],
      '购物': ['超市', '商场', '淘宝', '京东', '拼多多', '便利店', '百货', '商店'],
      '娱乐': ['电影', '游戏', 'KTV', '健身', '旅游', '酒店', '门票', '景区'],
    };
    for (final entry in keywords.entries) {
      for (final kw in entry.value) {
        if (text.contains(kw)) return entry.key;
      }
    }
    return null;
  }

  void dispose() {}
}
