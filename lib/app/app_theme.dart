/// Material 3 主题工厂：黑白两套同源派生，全应用唯一主题来源。
library;

// CupertinoPageTransitionsBuilder 定义在 cupertino.dart，material.dart 不再转发导出。
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/constants/dimen.dart';
import '../core/constants/theme.dart';

/// ThemeSetting → ThemeMode 映射。
ThemeMode themeModeOf(ThemeSetting setting) => switch (setting) {
  ThemeSetting.system => ThemeMode.system,
  ThemeSetting.light => ThemeMode.light,
  ThemeSetting.dark => ThemeMode.dark,
};

abstract final class AppTheme {
  /// 中性 seed 色（黑白灰基调）。
  static const seedColor = Color(0xFF6B7280);

  /// 全局字体族（对应 pubspec.yaml 中注册的 HarmonyOS Sans SC）。
  static const fontFamily = 'HarmonyOS Sans SC';

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      // 二级页 push/pop 统一为 iOS 风格横向滑入滑出（各平台一致）；不影响 Dialog/BottomSheet。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        indicatorColor: scheme.secondaryContainer,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimen.rMd)),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimen.rMd)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.rMd)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimen.rSm),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimen.rSm)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 0.5),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimen.rSm)),
      ),
    );
  }
}
