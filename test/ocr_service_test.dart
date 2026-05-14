import 'package:flutter_test/flutter_test.dart';

// Test the OCR extraction regex patterns directly
// These mirror the patterns in lib/services/ocr_service.dart

void main() {
  group('Amount extraction', () {
    double? extractAmount(String text) {
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

    test('extracts 微信 payment amount', () {
      final text = '实付 ¥36.50';
      expect(extractAmount(text), 36.50);
    });

    test('extracts 支付宝 payment', () {
      final text = '合计：128.00';
      expect(extractAmount(text), 128.00);
    });

    test('extracts amount with ￥ symbol', () {
      final text = '消费金额 ￥88.00';
      expect(extractAmount(text), 88.00);
    });

    test('extracts decimal amount', () {
      final text = '付款 15.5';
      expect(extractAmount(text), 15.5);
    });

    test('returns null for no amount', () {
      expect(extractAmount('hello world'), null);
    });

    test('rejects unreasonable amounts', () {
      // 100000+ is filtered
      expect(extractAmount('¥ 999999.00'), null);
    });
  });

  group('Payment extraction', () {
    String? extractPayment(String text) {
      if (text.contains('微信') || text.contains('WeChat')) return '微信';
      if (text.contains('支付宝') || text.contains('Alipay')) return '支付宝';
      if (text.contains('银行卡') || text.contains('银联') || text.contains('刷卡')) return '银行卡';
      return null;
    }

    test('detects WeChat', () {
      expect(extractPayment('微信支付'), '微信');
    });

    test('detects Alipay', () {
      expect(extractPayment('支付宝扫码'), '支付宝');
    });

    test('detects bank card', () {
      expect(extractPayment('银联刷卡'), '银行卡');
    });

    test('returns null when unknown', () {
      expect(extractPayment('现金支付'), null);
    });
  });

  group('Datetime extraction', () {
    String? extractDatetime(String text) {
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

    test('extracts Chinese date format', () {
      expect(extractDatetime('2024年12月15日 14:30'), '2024-12-15 14:30:00');
    });

    test('extracts dash date format', () {
      expect(extractDatetime('2024-01-05 09:20'), '2024-01-05 09:20:00');
    });

    test('extracts slash date format', () {
      expect(extractDatetime('2024/06/20 18:45'), '2024-06-20 18:45:00');
    });

    test('returns null for no date', () {
      expect(extractDatetime('no date here'), null);
    });
  });

  group('Merchant extraction', () {
    String? extractMerchant(List<String> lines, String? payment) {
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

    test('extracts merchant name', () {
      final lines = ['星巴克咖啡', '实付 ¥36.00', '2024-01-05'];
      expect(extractMerchant(lines, '微信'), '星巴克咖啡');
    });

    test('skips payment lines', () {
      final lines = ['微信支付', '超市购物'];
      expect(extractMerchant(lines, '微信'), '超市购物');
    });
  });

  group('Category extraction', () {
    String? extractCategory(String text) {
      const keywords = {
        '餐饮': ['餐', '饭', '吃', '食堂', '外卖', '午餐', '早餐', '晚餐', '美食', 'KFC', '麦当劳', '星巴克', '咖啡', '奶茶', '面', '粉', '饼'],
        '交通': ['打车', '滴滴', '公交', '地铁', '加油', '停车', '高铁', '机票', '出租车', '行程'],
        '购物': ['超市', '商场', '淘宝', '京东', '拼多多', '便利店', '百货', '商店'],
        '娱乐': ['电影', '游戏', 'KTV', '健身', '旅游', '酒店', '门票', '景区'],
        '医疗': ['医院', '药店', '医药', '诊所', '体检', '药'],
        '居住': ['房租', '水电', '物业', '燃气', '暖气'],
      };
      for (final entry in keywords.entries) {
        for (final kw in entry.value) {
          if (text.contains(kw)) return entry.key;
        }
      }
      return null;
    }

    test('detects restaurant', () {
      expect(extractCategory('麦当劳餐厅'), '餐饮');
    });

    test('detects transport', () {
      expect(extractCategory('滴滴出行'), '交通');
    });

    test('detects shopping', () {
      expect(extractCategory('京东商城'), '购物');
    });

    test('detects medical', () {
      expect(extractCategory('药店'), '医疗');
    });

    test('detects housing', () {
      expect(extractCategory('房租缴费'), '居住');
    });
  });
}
