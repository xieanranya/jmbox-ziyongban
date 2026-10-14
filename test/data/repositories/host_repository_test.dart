import 'package:flutter_test/flutter_test.dart';
import 'package:jmbox/core/constants/app_constants.dart';
import 'package:jmbox/data/repositories/host_repository.dart';

void main() {
  test('默认主机保留配置顺序且列表只读', () {
    final repository = HostRepository();
    expect(repository.apiHost(), kDefaultApiHosts.first);
    expect(repository.imageHost(), kDefaultImageHosts.first);
    expect(repository.apiHostList(), kDefaultApiHosts);
    expect(() => repository.apiHostList().add('https://x.test'), throwsUnsupportedError);
  });

  test('固定 API 主机先规范化，不在列表则回退第一台', () {
    final repository = HostRepository();
    repository.applyApiSelection('${kDefaultApiHosts[1]}/path');
    expect(repository.apiHost(), kDefaultApiHosts[1]);
    repository.applyApiSelection('https://not-in-list.test');
    expect(repository.apiHost(), kDefaultApiHosts.first);
  });

  test('未注入 setting 回调时刷新图片域名不改变列表', () async {
    final repository = HostRepository();
    await repository.refreshImageHosts();
    expect(repository.imageHostList(), kDefaultImageHosts);
  });

  test('服务端推荐图片主机规范化、置顶并用于自动模式', () async {
    final repository = HostRepository();
    repository.setSettingFetcher(() async => ' https://new-image.test/path ');
    await repository.refreshImageHosts();
    repository.applyImageSelection(auto: true, host: '');
    expect(repository.imageHost(), 'https://new-image.test');
    expect(repository.imageHostList().first, 'https://new-image.test');
  });

  test('手动图片主机优先，非法值回退当前列表第一台', () async {
    final repository = HostRepository();
    repository.setSettingFetcher(() async => 'https://new-image.test');
    await repository.refreshImageHosts();
    repository.applyImageSelection(auto: false, host: kDefaultImageHosts[2]);
    expect(repository.imageHost(), kDefaultImageHosts[2]);
    repository.applyImageSelection(auto: false, host: 'invalid host');
    expect(repository.imageHost(), 'https://new-image.test');
  });
}
