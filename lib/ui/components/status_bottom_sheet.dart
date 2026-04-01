import 'package:flutter/material.dart';
import '../../domain/model/book.dart';
import '../theme/app_colors.dart';

class StatusBottomSheet extends StatelessWidget {
  final ReadingStatus? currentStatus;
  final ValueChanged<ReadingStatus> onStatusSelected;

  const StatusBottomSheet({
    super.key,
    this.currentStatus,
    required this.onStatusSelected,
  });

  static Future<ReadingStatus?> show(
    BuildContext context, {
    ReadingStatus? currentStatus,
  }) {
    return showModalBottomSheet<ReadingStatus>(
      context: context,
      builder: (context) => StatusBottomSheet(
        currentStatus: currentStatus,
        onStatusSelected: (status) => Navigator.pop(context, status),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('독서 상태', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...ReadingStatus.values.map((status) => _StatusTile(
                status: status,
                isSelected: status == currentStatus,
                onTap: () => onStatusSelected(status),
              )),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final ReadingStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusTile({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.statusColor(status.index).withValues(alpha: 0.1)
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: AppColors.statusColor(status.index),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              status.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
