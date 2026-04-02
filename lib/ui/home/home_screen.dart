import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/model/book.dart';
import '../../providers/book_providers.dart';
import '../components/book_card.dart';
import '../components/book_list_tile.dart';
import '../components/empty_state.dart';
import '../components/status_bottom_sheet.dart';
import '../theme/app_colors.dart';

class HomeScreen extends ConsumerStatefulWidget {
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
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    // 홈 진입 시 자동 동기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncProvider.notifier).sync();
    });
  }

  Future<void> _onRefresh() async {
    final repo = ref.read(bookRepositoryProvider);
    await repo.syncAll();
    ref.read(booksRefreshProvider.notifier).refresh();
    ref.invalidate(filteredBooksProvider);
    ref.invalidate(groupedBooksProvider);
    ref.invalidate(booksProvider);
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      // 2초 내 두 번 → 종료
      SystemNavigator.pop();
      return true;
    }
    _lastBackPress = now;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('한 번 더 누르면 앱이 종료됩니다'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final groupedAsync = ref.watch(groupedBooksProvider);
    final selectedFilter = ref.watch(selectedStatusFilterProvider);
    final viewMode = ref.watch(viewModeProvider);
    final sortMode = ref.watch(sortModeProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('소피의 서재'),
          automaticallyImplyLeading: false, // 뒤로가기 화살표 제거
          actions: [
            // macOS/데스크탑: 새로고침 버튼
            if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows))
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 22),
                tooltip: '새로고침',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await _onRefresh();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('동기화 완료'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            PopupMenuButton<SortMode>(
              icon: const Icon(Icons.sort_rounded, size: 22),
              tooltip: '정렬',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (mode) {
                ref.read(sortModeProvider.notifier).set(mode);
              },
              itemBuilder: (_) => [
                _sortMenuItem(SortMode.status, '기본 정렬', sortMode),
                _sortMenuItem(SortMode.title, '이름순', sortMode),
                _sortMenuItem(SortMode.author, '작가별', sortMode),
                _sortMenuItem(SortMode.date, '날짜별', sortMode),
              ],
            ),
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
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: widget.onSearchTap,
              tooltip: '책 검색',
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: widget.onSettingsTap,
              tooltip: '설정',
            ),
          ],
        ),
        body: Column(
          children: [
            _FilterChips(
              selected: selectedFilter,
              onSelected: (status) {
                ref.read(selectedStatusFilterProvider.notifier).set(status);
              },
            ),
            Expanded(
              child: groupedAsync.when(
                data: (grouped) {
                  final totalBooks = grouped.values
                      .fold<int>(0, (sum, list) => sum + list.length);

                  if (totalBooks == 0) {
                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: AppColors.primary,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: EmptyState(
                              title: selectedFilter != null
                                  ? '"${selectedFilter.label}" 상태의 책이 없어요'
                                  : '아직 등록된 책이 없어요',
                              subtitle: '오른쪽 위 검색 버튼으로 책을 추가해보세요',
                              action: selectedFilter != null
                                  ? TextButton(
                                      onPressed: () {
                                        ref
                                            .read(selectedStatusFilterProvider
                                                .notifier)
                                            .set(null);
                                      },
                                      child: const Text('전체 보기'),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppColors.primary,
                    child: _GroupedBookView(
                      grouped: grouped,
                      viewMode: viewMode,
                      showHeaders: sortMode != SortMode.title,
                      onBookTap: widget.onBookTap,
                      onStatusChange: (book, status) async {
                        final repo = ref.read(bookRepositoryProvider);
                        await repo.updateStatus(book.id!, status);
                        ref.read(booksRefreshProvider.notifier).refresh();
                        ref.invalidate(filteredBooksProvider);
                        ref.invalidate(groupedBooksProvider);
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: '오류가 발생했어요',
                  subtitle: e.toString(),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: widget.onSearchTap,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }

  PopupMenuItem<SortMode> _sortMenuItem(
      SortMode mode, String label, SortMode current) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          if (mode == current)
            const Icon(Icons.check_rounded,
                size: 18, color: AppColors.primary)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

// ---- 필터 칩 ----
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
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        for (final entry in grouped.entries) ...[
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
                  childAspectRatio: 0.48,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
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
