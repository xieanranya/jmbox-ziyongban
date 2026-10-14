/// 每周连载更新列表页：星期 × 类型。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/filter_bar.dart';
import '../../shared/widgets/remote_grid_page.dart';
import '../../data/providers.dart';

/// 星期短名（下标 0 = 周一）。
const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

class SerializationPage extends ConsumerStatefulWidget {
  const SerializationPage({super.key, required this.initialDate, required this.title});

  /// 初始星期：'0' 全部 / '1'~'7' 周一~周日。
  final String initialDate;

  final String title;

  @override
  ConsumerState<SerializationPage> createState() => _SerializationPageState();
}

class _SerializationPageState extends ConsumerState<SerializationPage> {
  static const _serialTypes = [('all', '全部'), ('manga', '日漫'), ('hanman', '韩漫')];

  late String _date = widget.initialDate;
  String _type = 'all';

  @override
  Widget build(BuildContext context) {
    return RemoteGridPage(
      title: widget.title,
      refreshKey: (_date, _type),
      filterBar: FilterBar(
        children: [
          FilterDropdown<String>(
            prefix: '星期',
            value: _date,
            entries: [
              for (var i = 0; i < _weekdays.length; i++) MapEntry('${i + 1}', '周${_weekdays[i]}'),
            ],
            onChanged: (v) => setState(() => _date = v),
          ),
          FilterDropdown<String>(
            prefix: '类型',
            value: _type,
            entries: [for (final (value, label) in _serialTypes) MapEntry(value, label)],
            onChanged: (v) => setState(() => _type = v),
          ),
        ],
      ),
      fetchPage: (page) async {
        final list = await ref.read(apiRepositoryProvider).getSerialization(_date, _type, page);
        return (list, null); // 无总数接口，靠空页判底
      },
    );
  }
}
