import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../domain/model/book.dart';
import '../../providers/book_providers.dart';
import '../components/status_bottom_sheet.dart';
import '../theme/app_colors.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const SearchScreen({super.key, required this.onBack});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 자동 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).set(query);
    });
  }

  Future<void> _addBook(Book book) async {
    final repo = ref.read(bookRepositoryProvider);

    // 이미 등록된 책인지 확인
    if (book.isbn.isNotEmpty && await repo.isBookExists(book.isbn)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 등록된 책이에요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 상태 선택 바텀시트
    if (!mounted) return;
    final status = await StatusBottomSheet.show(context);
    if (status == null) return;

    final bookToSave = book.copyWith(
      status: status,
      addedAt: DateTime.now(),
      finishedAt: status == ReadingStatus.finished ? DateTime.now() : null,
    );

    final newId = await repo.addBook(bookToSave);
    ref.invalidate(filteredBooksProvider);
    ref.read(booksRefreshProvider.notifier).refresh();

    if (mounted) {
      // 홈으로 돌아간 뒤 상세 페이지로 이동 (뒤로가기 시 홈으로)
      context.go('/');
      // 약간의 딜레이 후 push (라우트 전환 완료 후)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          context.push('/detail/$newId');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            ref.read(searchQueryProvider.notifier).set('');
            widget.onBack();
          },
        ),
        title: const Text('책 검색'),
      ),
      body: Column(
        children: [
          // 검색바
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '책 제목, 저자, 출판사로 검색',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchQueryProvider.notifier).set('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          // 검색 결과
          Expanded(
            child: searchResults.when(
              data: (books) {
                if (ref.read(searchQueryProvider).isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_rounded, size: 48, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        const Text(
                          '읽고 싶은 책을 검색해보세요',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (books.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        const Text(
                          '검색 결과가 없어요',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _SearchResultTile(
                      book: books[index],
                      onTap: () => _addBook(books[index]),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    const Text(
                      '검색 중 오류가 발생했어요',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.toString(),
                      style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _SearchResultTile({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 표지
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 80,
                child: book.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: book.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: AppColors.creamLight,
                          child: const Icon(Icons.menu_book_rounded,
                              size: 24, color: AppColors.textHint),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.creamLight,
                          child: const Icon(Icons.menu_book_rounded,
                              size: 24, color: AppColors.textHint),
                        ),
                      )
                    : Container(
                        color: AppColors.creamLight,
                        child: const Icon(Icons.menu_book_rounded,
                            size: 24, color: AppColors.textHint),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${book.author} · ${book.publisher}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 추가 아이콘
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
