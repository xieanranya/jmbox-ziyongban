/// 代理配置与 AppConfig 新字段（画质档位 / 代理）单测。
///
/// 运行：flutter test test/features/settings/proxy_config_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/core/constants/enhance.dart';
import 'package:jmbox/core/network/proxy_config.dart';
import 'package:jmbox/data/models/config.dart';

void main() {
  group('ProxyConfig', () {
    test('默认直连', () {
      const p = ProxyConfig();
      expect(p.enabled, isFalse);
      expect(p.findProxyValue, isNull);
      expect(p.valid, isFalse);
    });

    test('启用后输出 PROXY 指令', () {
      const p = ProxyConfig(enabled: true, host: '127.0.0.1', port: 7890);
      expect(p.findProxyValue, 'PROXY 127.0.0.1:7890');
      expect(p.valid, isTrue);
      expect(p.display, '127.0.0.1:7890');
    });

    test('空主机 / 非法端口视为未启用', () {
      expect(const ProxyConfig(enabled: true, host: '  ', port: 7890).findProxyValue, isNull);
      expect(const ProxyConfig(enabled: true, host: '127.0.0.1', port: 0).findProxyValue, isNull);
      expect(const ProxyConfig(enabled: true, host: '127.0.0.1', port: 70000).findProxyValue, isNull);
    });
  });

  group('AppConfig 新字段', () {
    test('JSON 往返含画质档位与代理', () {
      const config = AppConfig(
        enhanceLevel: EnhanceLevel.ultra,
        proxyEnabled: true,
        proxyHost: '10.0.0.2',
        proxyPort: 1080,
      );
      final restored = AppConfig.fromJson(config.toJson());
      expect(restored.enhanceLevel, EnhanceLevel.ultra);
      expect(restored.proxyEnabled, isTrue);
      expect(restored.proxyHost, '10.0.0.2');
      expect(restored.proxyPort, 1080);
      expect(restored.proxyDisplay, '10.0.0.2:1080');
    });

    test('旧配置缺字段回落默认值', () {
      final config = AppConfig.fromJson(const {'username': 'a'});
      expect(config.enhanceLevel, EnhanceLevel.off);
      expect(config.proxyEnabled, isFalse);
      expect(config.proxyHost, '127.0.0.1');
      expect(config.proxyPort, 7890);
    });

    test('未知档位值回落 off', () {
      final config = AppConfig.fromJson(const {'enhance_level': 'quantum'});
      expect(config.enhanceLevel, EnhanceLevel.off);
    });

    test('copyWith 只改目标字段', () {
      const config = AppConfig(enhanceLevel: EnhanceLevel.off);
      final updated = config.copyWith(enhanceLevel: EnhanceLevel.strong, proxyPort: 8080);
      expect(updated.enhanceLevel, EnhanceLevel.strong);
      expect(updated.proxyPort, 8080);
      expect(updated.proxyEnabled, isFalse); // 未动
      expect(updated.themeSetting, config.themeSetting); // 未动
    });
  });
}
