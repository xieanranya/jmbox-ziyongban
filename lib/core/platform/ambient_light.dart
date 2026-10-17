/// 环境光传感器（Android 平台通道 jmbox/ambient_light）。
///
/// 护眼模式据此自适应滤镜强度：环境越暗滤蓝光越强，环境越亮越接近原色。
/// 设备无光线传感器时流会报错后关闭，调用方回退固定强度即可。
library;

import 'package:flutter/services.dart';

abstract final class AmbientLight {
  static const _channel = EventChannel('jmbox/ambient_light');

  /// 共享广播流：多个功能（护眼/自动亮度）监听同一流，原生侧只注册一次。
  static Stream<double>? _cached;

  /// 环境光照度（lux）广播流。
  static Stream<double> get light =>
      _cached ??= _channel.receiveBroadcastStream().map((e) => (e as num).toDouble());
}
