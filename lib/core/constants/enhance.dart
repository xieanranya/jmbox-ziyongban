/// 画质增强档位：作用于阅读器章节图的增强与超分放大。
///
/// - [off] 关闭：原图直显，零开销。
/// - [standard] 标准：USM 锐化 + 清晰度/对比度，不放大（原图已够大时选它）。
/// - [strong] 增强：Lanczos 超分放大到屏幕物理像素宽 + 强锐化。
/// - [ultra] 超级：更大放大（封顶）+ 降噪 + 最强锐化，较吃性能与电量。
/// - [ai] AI 超分：Real-ESRGAN 神经网络逐块推理，真·细节重建；每页数秒，仅按需使用。
enum EnhanceLevel {
  off('off', '关闭', '原图直显，不做任何处理'),
  standard('standard', '标准', '锐化 + 清晰度提升，不放大'),
  strong('strong', '增强', '超分放大至屏幕像素 + 强锐化'),
  ultra('ultra', '超级', '更大放大 + 降噪 + 最强锐化，较吃性能'),
  ai('ai', 'AI 超分', '神经网络推理重建细节，每页约数秒');

  const EnhanceLevel(this.value, this.label, this.description);

  /// 存储值（config.json）。
  final String value;

  /// 展示名。
  final String label;

  /// 一句话说明。
  final String description;

  /// 存储值 → 枚举；未知值回落 [off]（向后兼容旧配置）。
  static EnhanceLevel fromValue(String? value) {
    return EnhanceLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EnhanceLevel.off,
    );
  }

  /// 是否开启（非 [off]）。
  bool get enabled => this != EnhanceLevel.off;

  /// 是否走 AI 模型推理（而非经典算法管线）。
  bool get isAi => this == EnhanceLevel.ai;
}
