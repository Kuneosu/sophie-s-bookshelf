import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_providers.dart';
import '../../providers/book_providers.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const SettingsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final userEmail = ref.watch(currentUserEmailProvider);
    final syncStatus = ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack,
        ),
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 계정 섹션
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Text(
              '계정',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (isLoggedIn) ...[
            _SettingsTile(
              icon: Icons.person_rounded,
              title: userEmail ?? '로그인됨',
              subtitle: '로그인 중',
              onTap: null,
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.sync_rounded,
              title: '동기화',
              subtitle: _syncStatusText(syncStatus),
              onTap: syncStatus == SyncStatus.syncing
                  ? null
                  : () => ref.read(syncProvider.notifier).sync(),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.logout_rounded,
              title: '로그아웃',
              subtitle: '계정에서 로그아웃합니다',
              onTap: () => _handleLogout(context, ref),
              dangerous: true,
            ),
          ] else
            _SettingsTile(
              icon: Icons.login_rounded,
              title: '로그인',
              subtitle: '로그인하여 데이터를 동기화하세요',
              onTap: () => context.go('/login'),
            ),
          const SizedBox(height: 24),

          // 데이터 섹션
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Text(
              '데이터 관리',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.upload_rounded,
            title: 'JSON 내보내기',
            subtitle: '독서 기록을 JSON 파일로 저장',
            onTap: () => _exportJson(context, ref),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.download_rounded,
            title: 'JSON 가져오기 (병합)',
            subtitle: '기존 데이터를 유지하고 새 데이터 추가',
            onTap: () => _importJson(context, ref, replace: false),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.swap_horiz_rounded,
            title: 'JSON 가져오기 (덮어쓰기)',
            subtitle: '기존 데이터를 삭제하고 새 데이터로 교체',
            onTap: () => _importJson(context, ref, replace: true),
            dangerous: true,
          ),
          const SizedBox(height: 24),
          // 앱 정보
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Text(
              '앱 정보',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Bookshelf',
            subtitle: 'v1.0.0',
            onTap: null,
          ),
        ],
      ),
    );
  }

  String _syncStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return '탭하여 동기화';
      case SyncStatus.syncing:
        return '동기화 중...';
      case SyncStatus.success:
        return '동기화 완료!';
      case SyncStatus.error:
        return '동기화 실패 - 다시 시도해주세요';
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?\n로컬 데이터는 유지됩니다.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref.read(authProvider.notifier).signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(bookRepositoryProvider);
      final json = await repo.exportToJson();

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/bookshelf_$timestamp.json');
      await file.writeAsString(json);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('내보내기 완료'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('파일이 저장되었습니다.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    file.path,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: json));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('JSON이 클립보드에 복사되었습니다'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('클립보드에 복사'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('내보내기 실패: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importJson(
    BuildContext context,
    WidgetRef ref, {
    required bool replace,
  }) async {
    // 클립보드에서 JSON 가져오기
    final controller = TextEditingController();

    if (!context.mounted) return;
    final json = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(replace ? '데이터 덮어쓰기' : '데이터 가져오기'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (replace)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_rounded, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '기존 데이터가 모두 삭제됩니다!',
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text('JSON 데이터를 붙여넣기 해주세요:',
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '{"version": 1, "books": [...]}',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) {
                controller.text = data!.text!;
              }
            },
            child: const Text('클립보드에서 붙여넣기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('가져오기'),
          ),
        ],
      ),
    );

    if (json == null || json.trim().isEmpty) return;

    try {
      final repo = ref.read(bookRepositoryProvider);
      final count = await repo.importFromJson(json, replace: replace);
      ref.read(booksRefreshProvider.notifier).refresh();
      ref.invalidate(filteredBooksProvider);
      ref.invalidate(groupedBooksProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count권의 책을 가져왔습니다'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('가져오기 실패: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool dangerous;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.dangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: dangerous
              ? Border.all(color: Colors.red.withValues(alpha: 0.2))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: dangerous
                    ? Colors.red.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 20,
                  color: dangerous ? Colors.red : AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: dangerous ? Colors.red : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}
