/// 系统屏幕亮度调节（Android 平台通道 jmbox/screen_brightness）。
///
/// 两层语义：
/// - 窗口亮度（[setWindowBrightness]）：只影响本应用窗口，即时生效、无需权限，
///   退出阅读器时传 null 清除覆盖，屏幕亮度交还系统；
/// - 系统亮度（[setSystemBrightness]）：写入全局系统设置，需用户在系统设置里
///   授予「修改系统设置」权限（[canWriteSettings] 查询 / [requestWriteSettings] 引导）。
library;

import 'package:flutter/services.dart';

abstract final class ScreenBrightness {
  static const _channel = MethodChannel('jmbox/screen_brightness');

  /// 设置窗口亮度（0.01~1.0；null 清除覆盖）。返回通道是否可用。
  static Future<bool> setWindowBrightness(double? value) async {
    try {
      await _channel.invokeMethod<void>('setWindowBrightness', {'value': value});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 当前系统亮度 0~1；读取失败返回 -1。
  static Future<double> systemBrightness() async {
    try {
      final v = await _channel.invokeMethod<double>('getSystemBrightness');
      return v ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// 写入系统亮度（0~255）。未授权或写入失败返回 false。
  static Future<bool> setSystemBrightness(int value255) async {
    try {
      return await _channel.invokeMethod<bool>('setSystemBrightness',
            {'value': value255}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 是否已授予「修改系统设置」权限。
  static Future<bool> canWriteSettings() async {
    try {
      return await _channel.invokeMethod<bool>('canWriteSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 跳转系统「修改系统设置」授权页。
  static Future<void> requestWriteSettings() async {
    try {
      await _channel.invokeMethod<void>('requestWriteSettings');
    } catch (_) {}
  }

  /// 恢复系统自动亮度模式（SCREEN_BRIGHTNESS_MODE=AUTOMATIC）。
  /// 用于关闭 App 内「自动亮度」时把控制权交还系统；未授权时静默失败。
  static Future<bool> restoreAutoMode() async {
    try {
      return await _channel.invokeMethod<bool>('restoreAutoBrightnessMode') ??
          false;
    } catch (_) {
      return false;
    }
  }
}
