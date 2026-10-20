/// AI 超分模块单测：资产声明有效性、模型文件格式、枚举序列化。
///
/// 运行：flutter test test/features/reader/enhance/ai_super_res_test.dart
///
/// 注意：真实推理需要设备（GPU/CPU 委托 + native 库），单测环境只验证
/// 资产链路与纯逻辑；推理冒烟请在真机上开「AI 超分」档验证。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/core/constants/enhance.dart';
import 'package:jmbox/data/models/config.dart';
import 'package:jmbox/features/reader/enhance/ai_super_res.dart';

void main() {
  // rootBundle 走平台通道，需先初始化测试 binding。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI 模型资产', () {
    test('模型可经 rootBundle 加载且为合法 TFLite 文件', () async {
      final bytes = await loadAiModelBuffer();
      // TFLite flatbuffer 魔数位于偏移 4："TFL3"。
      expect(bytes.length, greaterThan(1024 * 1024)); // 约 4.9MB
      expect(bytes.length, lessThan(10 * 1024 * 1024));
      expect(bytes[4], 0x54); // 'T'
      expect(bytes[5], 0x46); // 'F'
      expect(bytes[6], 0x4c); // 'L'
      expect(bytes[7], 0x33); // '3'
    });

    test('pixelsToImage 往返尺寸正确', () async {
      const w = 8;
      const h = 12;
      final px = Uint8List(w * h * 4);
      for (var i = 0; i < px.length; i += 4) {
        px[i] = 10;
        px[i + 1] = 20;
        px[i + 2] = 30;
        px[i + 3] = 255;
      }
      final image = await pixelsToImage(px, w, h);
      expect(image.width, w);
      expect(image.height, h);
      image.dispose();
    });
  });

  group('EnhanceLevel.ai 序列化', () {
    test('AI 档 JSON 往返', () {
      const config = AppConfig(enhanceLevel: EnhanceLevel.ai);
      final restored = AppConfig.fromJson(config.toJson());
      expect(restored.enhanceLevel, EnhanceLevel.ai);
      expect(restored.enhanceLevel.isAi, isTrue);
      expect(restored.enhanceLevel.enabled, isTrue);
    });

    test('ai 档位值与图标语义', () {
      expect(EnhanceLevel.fromValue('ai'), EnhanceLevel.ai);
      expect(EnhanceLevel.off.isAi, isFalse);
      expect(EnhanceLevel.ultra.isAi, isFalse);
    });
  });
}
