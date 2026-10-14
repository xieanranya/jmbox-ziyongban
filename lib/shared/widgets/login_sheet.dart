import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/dimen.dart';
import '../../../data/providers.dart';
import '../../../data/session_providers.dart';

/// 弹出底部登录面板；返回是否登录成功。
Future<bool> showLoginSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _LoginSheet(),
  );
  return result ?? false;
}

/// 未登录时弹出登录面板；返回是否已登录（含登录成功）。
Future<bool> ensureLoggedIn(BuildContext context, WidgetRef ref) async {
  if (ref.read(sessionProvider).value != null) return true;
  return showLoginSheet(context);
}

class _LoginSheet extends ConsumerStatefulWidget {
  const _LoginSheet();

  @override
  ConsumerState<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends ConsumerState<_LoginSheet> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 预填已保存的用户名（退出登录只清密码，用户名保留）。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final config = ref.read(configRepositoryProvider).read();
      if (config.username.isNotEmpty && mounted) {
        _username.text = config.username;
      }
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).signIn(username, password);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登录失败：$e')));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Dimen.lg,
          Dimen.lg,
          Dimen.lg,
          Dimen.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Dimen.md,
            children: [
              Text('登录', style: theme.textTheme.titleLarge),
              TextField(
                controller: _username,
                enabled: !_busy,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: '账号',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
