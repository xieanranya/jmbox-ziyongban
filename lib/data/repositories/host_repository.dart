/// 域名仓库：维护 API/图片两个主机列表与选路，对外提供取 host 的回调。
///
/// 选路规则（两侧一致）：固定主机在列表内 → 用它；否则回退列表第一台。
/// 运行期主机冻结（会话按域名签发，换机必 401；图片侧行为对齐），
/// 选路只在 bootstrap 与设置页手动切换时发生，域名失效靠重启/重拉列表自愈。
library;

import '../../core/constants/app_constants.dart';
import '../../core/network/api_domain.dart';
import '../../core/utils/host.dart';

class HostRepository {
  HostRepository()
    : _apiHosts = _normalize(kDefaultApiHosts),
      _imageHosts = _normalize(kDefaultImageHosts);

  final ApiDomainFetcher _fetcher = ApiDomainFetcher();

  Future<String?> Function()? _settingFetcher;

  final List<String> _apiHosts;
  final List<String> _imageHosts;

  /// 固定的主机；null 表示未固定（取列表第一台）。
  String? _pinnedApiHost;
  String? _pinnedImageHost;

  /// 当前 API 主机（以回调注入 ApiClient）。
  String? apiHost() => _current(_apiHosts, _pinnedApiHost);

  /// 当前图片主机（以回调注入 ImageClient）。
  String? imageHost() => _current(_imageHosts, _pinnedImageHost);

  /// 全部 API 主机（设置页选项列表）。
  List<String> apiHostList() => List.unmodifiable(_apiHosts);

  /// 全部图片主机（设置页选项列表）。
  List<String> imageHostList() => List.unmodifiable(_imageHosts);

  /// 应用 API 域名选择：[host] 在当前列表内 → 固定它；否则回退列表第一台。
  /// 列表第一台随 bootstrap 的 refreshApiHosts 每次启动更新。
  void applyApiSelection(String host) => _pinnedApiHost = _pin(_apiHosts, host);

  /// 应用图片域名选择：auto → 固定最近一次拉到的服务端推荐主机；
  /// 否则 → 固定用户选定的 [host]。不在列表时回退列表第一台。
  void applyImageSelection({required bool auto, required String host}) =>
      _pinnedImageHost = _pin(_imageHosts, auto ? (_recommendedImageHost ?? '') : host);

  Future<void> refreshApiHosts() async {
    _insertInto(_apiHosts, await _fetcher.fetch());
  }

  /// 注入 /setting 取推荐图片主机的回调（返回 imageHost；失败抛出，调用方决定是否吞掉）。
  /// 由装配层在创建仓库后调用；未注入时 [refreshImageHosts] 不做任何事。
  void setSettingFetcher(Future<String?> Function() fetcher) => _settingFetcher = fetcher;

  /// 最近一次拉到的服务端推荐图片主机；未拉到过时为 null。
  String? _recommendedImageHost;

  /// 刷新图片域名：调已注入的 /setting 回调拿服务端推荐主机，记下并移到列表首位
  /// （未固定时的默认）。未注入回调时直接返回，不刷新。
  Future<void> refreshImageHosts() async {
    final fetcher = _settingFetcher;
    if (fetcher == null) return;
    final normalized = normalizedBaseUrlOrNull(await fetcher() ?? '');
    if (normalized == null) return;
    _recommendedImageHost = normalized;
    _insertInto(_imageHosts, [normalized]);
  }

  static String? _current(List<String> hosts, String? pinned) {
    // 固定值可能因列表换代而失效（pin 时校验过，之后 insert 的新列表不含它），
    // 每次取用再校验一次：失效即回退队首，与 bootstrap 的回退语义一致。
    if (pinned != null && hosts.contains(pinned)) return pinned;
    return hosts.isEmpty ? null : hosts.first;
  }

  /// 规范化并校验 [host] 在列表内，返回可固定的值；否则 null（回退第一台）。
  static String? _pin(List<String> hosts, String host) {
    final normalized = normalizedBaseUrlOrNull(host);
    return normalized != null && hosts.contains(normalized) ? normalized : null;
  }

  /// 插入主机列表（去重；新主机排在最前，已存在的也移到最前，
  /// 保证「未固定时取第一台」拿到的就是最新下发的首选）。
  static void _insertInto(List<String> hosts, List<String> incoming) {
    for (final raw in incoming) {
      final host = normalizedBaseUrlOrNull(raw);
      if (host == null) continue;
      hosts.remove(host);
      hosts.insert(0, host);
    }
  }

  static List<String> _normalize(List<String> hosts) =>
      hosts.map(normalizedBaseUrlOrNull).whereType<String>().toSet().toList();
}
