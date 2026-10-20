import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/core/constants/reader_config.dart';
import 'package:jmbox/features/reader/page_geometry.dart';

void main() {
  test('未测页面使用默认比例', () {
    final geometry = PageGeometry();
    expect(geometry.aspectOf(0), kDefaultPageAspect);
    expect(geometry.aspectOf(-1), kDefaultPageAspect);
  });

  test('本页实测值优先于章内估算', () {
    final geometry = PageGeometry();
    geometry.record(0, 1000, 1500);
    geometry.record(1, 1000, 1700);
    expect(geometry.aspectOf(0), closeTo(1.5, 1e-9));
    expect(geometry.aspectOf(9), closeTo(1.7, 1e-9));
  });

  test('非法页码或尺寸不会污染估算', () {
    final geometry = PageGeometry();
    geometry.record(-1, 100, 200);
    geometry.record(0, 0, 200);
    geometry.record(1, 100, 0);
    expect(geometry.aspectOf(5), kDefaultPageAspect);
  });

  test('异常比例被夹在安全上下限', () {
    final geometry = PageGeometry();
    geometry.record(0, 1000, 1);
    geometry.record(1, 1, 100000);
    expect(geometry.aspectOf(0), kMinPageAspect);
    expect(geometry.aspectOf(1), kMaxPageAspect);
  });

  test('同一页面重新测量后，中位数只统计该页最新值', () {
    final geometry = PageGeometry();
    geometry.record(0, 1000, 1000);
    geometry.record(1, 1000, 3000);
    geometry.record(0, 1000, 2000);

    // 当前有效页面值为 [2.0, 3.0]，上中位数应为 3.0；旧的 1.0 不应残留为额外样本。
    expect(geometry.aspectOf(99), closeTo(3.0, 1e-9));
  });

  test('样本超过上限仍保留每页精确实测值', () {
    final geometry = PageGeometry();
    for (var i = 0; i < kGeometrySampleLimit + 5; i++) {
      geometry.record(i, 1000, 1000 + i);
    }
    expect(geometry.aspectOf(0), closeTo(1.0, 1e-9));
    expect(geometry.aspectOf(kGeometrySampleLimit + 4), closeTo(1.02, 1e-9));
  });
}
