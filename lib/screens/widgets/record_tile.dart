import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A reusable list tile for displaying work, borrow, or settlement records.
class RecordTile extends StatelessWidget {
  final DateTime date;
  final RecordType recordType;
  final double amount;
  final String? note;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const RecordTile({
    super.key,
    required this.date,
    required this.recordType,
    required this.amount,
    this.note,
    this.subtitle,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM/dd');
    final numberFormat = NumberFormat('#,##0.00');

    final iconData = _getIcon();
    final iconColor = _getColor(theme);
    final typeLabel = _getTypeLabel();

    return Dismissible(
      key: ValueKey('${recordType.name}_${date.toIso8601String()}_$amount'),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.12),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Text(
          '¥${numberFormat.format(amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: recordType == RecordType.settlement
                ? Colors.green.shade700
                : (recordType == RecordType.borrow
                    ? Colors.red.shade700
                    : theme.colorScheme.onSurface),
          ),
        ),
        subtitle: Text(
          subtitle ?? _buildSubtitle(dateFormat, typeLabel, note),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          dateFormat.format(date),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _getIcon() {
    switch (recordType) {
      case RecordType.work:
        return Icons.work;
      case RecordType.borrow:
        return Icons.money_off;
      case RecordType.settlement:
        return Icons.account_balance_wallet;
    }
  }

  Color _getColor(ThemeData theme) {
    switch (recordType) {
      case RecordType.work:
        return theme.colorScheme.primary;
      case RecordType.borrow:
        return Colors.orange;
      case RecordType.settlement:
        return Colors.green;
    }
  }

  String _getTypeLabel() {
    switch (recordType) {
      case RecordType.work:
        return '记工';
      case RecordType.borrow:
        return '借支';
      case RecordType.settlement:
        return '结算';
    }
  }

  String _buildSubtitle(
    DateFormat dateFormat,
    String typeLabel,
    String? note,
  ) {
    final notePart = (note != null && note.isNotEmpty) ? ' · $note' : '';
    return '$typeLabel$notePart';
  }
}

enum RecordType { work, borrow, settlement }
