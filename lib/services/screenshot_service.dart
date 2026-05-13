import 'package:flutter/services.dart';

class ScreenshotService {
  static const _channel = MethodChannel('com.yingfeng.expense/screenshot');
  bool _isListening = false;

  Future<void> startListening(void Function() onScreenshot) async {
    if (_isListening) return;
    _isListening = true;

    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onScreenshotTaken') {
          onScreenshot();
        }
      });
      await _channel.invokeMethod('startListening');
    } catch (e) {
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;

    try {
      await _channel.invokeMethod('stopListening');
      _channel.setMethodCallHandler(null);
    } catch (e) {
      // ignore
    }
  }
}
