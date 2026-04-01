import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/model/book.dart';
import '../../providers/book_providers.dart';
import '../components/book_card.dart';
import '../components/empty_state.dart';
import '../components/status_bottom_sheet.dart';
import '../theme/app_colors.dart';

class HomeScreen extends ConsumerWidget {
  final void Function(int bookId) onBookTap;
  final VoidCallback onSearchTap;

  const HomeScreen({
    super.key,
    required this.onBookTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // refresh 트리거 감시
    ref.watch(booksRefreshProvider);
    final booksAsync = ref.watch(filteredBooksProvider);
    final selectedFilter = ref.watch(selectedStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 서재'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: onSearchTap,
            tooltip: '책 검색',
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 필터 칩
          _FilterChips(
            selected: selectedFilter,
            onSelected: (status) {
              ref.read(selectedStatusFilterProvider.notifier).set(status);
            },
          ),
          // 책 그리드
          Expanded(
            child: booksAsync.when(
              data: (books) {
                if (books.isEmpty) {
                  return EmptyState(
                    title: selectedFilter != null
                        ? '\'\${selectedFilter.label}\' 상태의 책이 없어요'
                        : '아직 등록된 책이 없어요',
                    subtitle: '오른쪽 위 검색 버튼으로 책을 추가해보세요',
                    action: selectedFilter != null
                        ? TextButton(
                            onPressed: () {
                              ref.read(selectedStatusFilterProvider.notifier).set(null);
                            },
                            child: const Text('전체 보기'),
                          )
                        : null,
                  );
                }
                return _BookGrid(
                  books: books,
                  onBookTap: onBookTap,
                  onStatusChange: (book, status) async {
                    final repo = ref.read(bookRepositoryProvider);
                    await repo.updateStatus(book.id!, status);
                    ref.invalidate(filteredBooksProvider);
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
}

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
                child: _chip(context, '\${s.emoji} \${s.label}', s),
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
      checkmarkColor: Colors.white,
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

class _BookGrid extends StatelessWidget {
  final List<Book> books;
  final void Function(int bookId) onBookTap;
  final void Function(Book book, ReadingStatus status) onStatusChange;

  const _BookGrid({
    required this.books,
    required this.onBookTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookCard(
          book: book,
          onTap: () => onBookTap(book.id!),
          onLongPress: () async {
            final status = await StatusBottomSheet.show(
              context,
              currentStatus: book.status,
            );
            if (status != null) {
              onStatusChange(book, status);
            }
          },
        );
      },
    );
  }
}
