import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../domain/model/book.dart';
import '../theme/app_colors.dart';

class BookListTile extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BookListTile({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
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
                width: 48,
                height: 68,
                child: book.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: book.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: AppColors.creamLight,
                          child: const Icon(Icons.menu_book_rounded,
                              size: 20, color: AppColors.textHint),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.creamLight,
                          child: const Icon(Icons.menu_book_rounded,
                              size: 20, color: AppColors.textHint),
                        ),
                      )
                    : Container(
                        color: AppColors.creamLight,
                        child: const Icon(Icons.menu_book_rounded,
                            size: 20, color: AppColors.textHint),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${book.author} · ${book.publisher}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _buildDateInfo(),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 상태 + 별점
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.statusColor(book.status.index)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    book.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusColor(book.status.index),
                    ),
                  ),
                ),
                if (book.rating != null && book.rating! > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) => Icon(
                      i < book.rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 12,
                      color: AppColors.accent,
                    )),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInfo() {
    final fmt = DateFormat('yy.MM.dd');
    String text;

    if (book.startedAt != null && book.finishedAt != null) {
      text = '${fmt.format(book.startedAt!)} ~ ${fmt.format(book.finishedAt!)}';
    } else if (book.startedAt != null) {
      text = '${fmt.format(book.startedAt!)} ~';
    } else {
      text = '등록: ${fmt.format(book.addedAt)}';
    }

    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.textHint,
      ),
    );
  }
}
