import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/model/book.dart';
import '../../providers/book_providers.dart';
import '../components/status_bottom_sheet.dart';
import '../theme/app_colors.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final int bookId;
  final VoidCallback onBack;

  const DetailScreen({
    super.key,
    required this.bookId,
    required this.onBack,
  });

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  late TextEditingController _memoController;
  bool _memoChanged = false;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController();
  }

  @override
  void dispose() {
    _saveMemo();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _saveMemo() async {
    if (!_memoChanged) return;
    final book = await ref.read(bookDetailProvider(widget.bookId).future);
    if (book == null) return;
    final updated = book.copyWith(memo: _memoController.text);
    await ref.read(bookRepositoryProvider).updateBook(updated);
    ref.invalidate(filteredBooksProvider);
  }

  Future<void> _changeStatus(Book book) async {
    final status = await StatusBottomSheet.show(
      context,
      currentStatus: book.status,
    );
    if (status == null) return;

    final updated = book.copyWith(
      status: status,
      finishedAt: status == ReadingStatus.finished ? DateTime.now() : null,
    );
    await ref.read(bookRepositoryProvider).updateBook(updated);
    ref.invalidate(bookDetailProvider(widget.bookId));
    ref.invalidate(filteredBooksProvider);
    ref.read(booksRefreshProvider.notifier).refresh();
  }

  Future<void> _updateRating(Book book, int rating) async {
    final updated = book.copyWith(rating: rating);
    await ref.read(bookRepositoryProvider).updateBook(updated);
    ref.invalidate(bookDetailProvider(widget.bookId));
  }

  Future<void> _deleteBook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('책 삭제'),
        content: const Text('이 책을 서재에서 삭제할까요?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(bookRepositoryProvider).deleteBook(widget.bookId);
      ref.invalidate(filteredBooksProvider);
      ref.read(booksRefreshProvider.notifier).refresh();
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookDetailProvider(widget.bookId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('삭제', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') _deleteBook();
            },
          ),
        ],
      ),
      body: bookAsync.when(
        data: (book) {
          if (book == null) {
            return const Center(child: Text('책을 찾을 수 없어요'));
          }

          // 메모 컨트롤러 초기화 (한 번만)
          if (_memoController.text.isEmpty && book.memo.isNotEmpty) {
            _memoController.text = book.memo;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                // 표지
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 160,
                      height: 230,
                      child: book.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: book.thumbnailUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppColors.creamLight,
                              child: const Icon(
                                Icons.menu_book_rounded,
                                size: 48,
                                color: AppColors.textHint,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 제목
                Text(
                  book.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // 저자 · 출판사
                Text(
                  '${book.author} · ${book.publisher}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // 상태 변경 버튼
                InkWell(
                  onTap: () => _changeStatus(book),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusColor(book.status.index)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.statusColor(book.status.index),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${book.status.emoji} ${book.status.label}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.statusColor(book.status.index),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.statusColor(book.status.index),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 별점 (완독인 경우)
                if (book.status == ReadingStatus.finished) ...[
                  const Text(
                    '평점',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => _updateRating(book, index + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            index < (book.rating ?? 0)
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.accent,
                            size: 36,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                ],

                // 메모
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '📝 메모',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _memoController,
                  maxLines: 3,
                  onChanged: (_) => _memoChanged = true,
                  decoration: const InputDecoration(
                    hintText: '이 책에 대한 메모를 남겨보세요...',
                  ),
                ),

                // 책 소개
                if (book.description.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '📋 책 소개',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      book.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}
