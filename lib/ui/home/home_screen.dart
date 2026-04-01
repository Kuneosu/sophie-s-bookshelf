import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/model/book.dart';
import '../../providers/book_providers.dart';
import '../components/book_card.dart';
import '../components/book_list_tile.dart';
import '../components/empty_state.dart';
import '../components/status_bottom_sheet.dart';
import '../theme/app_colors.dart';

class HomeScreen extends ConsumerWidget {
  final void Function(int bookId) onBookTap;
  final VoidCallback onSearchTap;
  final VoidCallback onSettingsTap;

  const HomeScreen({
    super.key,
    required this.onBookTap,
    required this.onSearchTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(groupedBooksProvider);
    final selectedFilter = ref.watch(selectedStatusFilterProvider);
    final viewMode = ref.watch(viewModeProvider);
    final groupMode = ref.watch(groupModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 서재'),
        actions: [
          // 그룹핑 메뉴
          PopupMenuButton<GroupMode>(
            icon: const Icon(Icons.filter_list_rounded, size: 22),
            tooltip: '그룹',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (mode) =>
                ref.read(groupModeProvider.notifier).set(mode),
            itemBuilder: (_) => [
              _groupMenuItem(GroupMode.none, '정렬 없음', groupMode),
              _groupMenuItem(GroupMode.author, '작가별', groupMode),
              _groupMenuItem(GroupMode.finishedMonth, '읽은 날짜별', groupMode),
            ],
          ),
          // 뷰 모드 전환
          IconButton(
            icon: Icon(
              viewMode == ViewMode.gallery
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              size: 22,
            ),
            tooltip: viewMode == ViewMode.gallery ? '리스트 뷰' : '갤러리 뷰',
            onPressed: () => ref.read(viewModeProvider.notifier).toggle(),
          ),
          // 검색
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: onSearchTap,
            tooltip: '책 검색',
          ),
          // 설정 (import/export)
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: onSettingsTap,
            tooltip: '설정',
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 필터 칩 (이모지 제거)
          _FilterChips(
            selected: selectedFilter,
            onSelected: (status) {
              ref.read(selectedStatusFilterProvider.notifier).set(status);
            },
          ),
          // 책 목록
          Expanded(
            child: groupedAsync.when(
              data: (grouped) {
                final totalBooks =
                    grouped.values.fold<int>(0, (sum, list) => sum + list.length);

                if (totalBooks == 0) {
                  return EmptyState(
                    title: selectedFilter != null
                        ? '"${selectedFilter.label}" 상태의 책이 없어요'
                        : '아직 등록된 책이 없어요',
                    subtitle: '오른쪽 위 검색 버튼으로 책을 추가해보세요',
                    action: selectedFilter != null
                        ? TextButton(
                            onPressed: () {
                              ref
                                  .read(selectedStatusFilterProvider.notifier)
                                  .set(null);
                            },
                            child: const Text('전체 보기'),
                          )
                        : null,
                  );
                }

                return _GroupedBookView(
                  grouped: grouped,
                  viewMode: viewMode,
                  showHeaders: groupMode != GroupMode.none,
                  onBookTap: onBookTap,
                  onStatusChange: (book, status) async {
                    final repo = ref.read(bookRepositoryProvider);
                    await repo.updateStatus(book.id!, status);
                    ref.read(booksRefreshProvider.notifier).refresh();
                    ref.invalidate(filteredBooksProvider);
                    ref.invalidate(groupedBooksProvider);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => EmptyState(
                emoji: '😥',
                title: '오류가 발생했어요',
                subtitle: e.toString(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onSearchTap,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  PopupMenuItem<GroupMode> _groupMenuItem(
      GroupMode mode, String label, GroupMode current) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          if (mode == current)
            const Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

// ---- 필터 칩 (이모지 제거) ----
class _FilterChips extends StatelessWidget {
  final ReadingStatus? selected;
  final ValueChanged<ReadingStatus?> onSelected;

  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _chip(context, '전체', null),
          const SizedBox(width: 8),
          ...ReadingStatus.values.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _chip(context, s.label, s),
              )),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, ReadingStatus? status) {
    final isSelected = selected == status;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(status),
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: status != null
          ? AppColors.statusColor(status.index)
          : AppColors.primary,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
      side: BorderSide.none,
    );
  }
}

// ---- 그룹핑된 책 뷰 ----
class _GroupedBookView extends StatelessWidget {
  final Map<String, List<Book>> grouped;
  final ViewMode viewMode;
  final bool showHeaders;
  final void Function(int bookId) onBookTap;
  final void Function(Book book, ReadingStatus status) onStatusChange;

  const _GroupedBookView({
    required this.grouped,
    required this.viewMode,
    required this.showHeaders,
    required this.onBookTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        for (final entry in grouped.entries) ...[
          // 그룹 헤더
          if (showHeaders && entry.key.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 책 목록
          if (viewMode == ViewMode.gallery)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final book = entry.value[index];
                    return BookCard(
                      book: book,
                      onTap: () => onBookTap(book.id!),
                      onLongPress: () => _showStatusSheet(context, book),
                    );
                  },
                  childCount: entry.value.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.55,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final book = entry.value[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: BookListTile(
                        book: book,
                        onTap: () => onBookTap(book.id!),
                        onLongPress: () => _showStatusSheet(context, book),
                      ),
                    );
                  },
                  childCount: entry.value.length,
                ),
              ),
            ),
        ],
        // 하단 패딩 (FAB 가리지 않도록)
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Future<void> _showStatusSheet(BuildContext context, Book book) async {
    final status = await StatusBottomSheet.show(
      context,
      currentStatus: book.status,
    );
    if (status != null) {
      onStatusChange(book, status);
    }
  }
}
