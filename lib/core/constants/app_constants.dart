/// 应用级常量：UA、版本、密钥、默认 scramble id、默认域名。
library;

/// 请求 User-Agent（模拟 Android 浏览器）。
const String kUserAgent =
    'Mozilla/5.0 (Linux; Android 16; PTP-AN10 Build/HONORPTP-AN10) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.7204.179 '
    'Mobile Safari/537.36';

/// 客户端版本号（参与 Tokenparam 计算）。
const String kAppVersion = '2.1.4';

/// 普通接口 Token 计算密钥。
const String kAppTokenSecret = '18comicAPP';

/// scramble 接口 Token 计算密钥。
const String kAppTokenSecret2 = '18comicAPPContent';

/// 响应数据 AES 解密密钥计算密钥。
const String kAppDataSecret = '185Hcomic3PAPP7R';

/// 图片解密默认 scramble id（接口解析失败时回退）。
const int kAppScrambleId = 220980;

/// API/图片单次调用的最大尝试次数（含首次）。每个失败候补最坏要等满一个超时，
/// 而用户正盯着这个转圈，3 次足够覆盖「一台坏了、下一台好」的常见情形。
const int kMaxAttempts = 3;

/// 默认 API 域名列表
const List<String> kDefaultApiHosts = [
  'https://www.cdngwc.cc',
  'https://www.cdngwc.net',
  'https://www.cdngwc.club',
  'https://www.cdnhjk.net',
];

/// 默认图片域名列表
const List<String> kDefaultImageHosts = [
  'https://cdn-msp.jmapiproxy1.cc',
  'https://cdn-msp.jmapiproxy2.cc',
  'https://cdn-msp2.jmapiproxy2.cc',
  'https://cdn-msp3.jmapiproxy2.cc',
];

/// 域名服务器 URL 列表
const List<String> kDomainServerUrls = [
  'https://rup4a04-c01.tos-ap-southeast-1.bytepluses.com/newsvr-2025.txt',
  'https://rup4a04-c02.tos-cn-hongkong.bytepluses.com/newsvr-2025.txt',
  'https://rup4a04-c03.tos-cn-beijing.bytepluses.com.cn/newsvr-2025.txt',
];

/// 域名服务器响应解密密钥。
const String kDomainServerSecret = 'diosfjckwpqpdfjkvnqQjsik';
