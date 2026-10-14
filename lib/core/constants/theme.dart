/// 主题设置枚举。
library;

enum ThemeSetting {
  system('system'),
  light('light'),
  dark('dark');

  const ThemeSetting(this.value);

  /// 存储值。
  final String value;
}
