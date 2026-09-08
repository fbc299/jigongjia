import 'package:flutter/material.dart';
import 'package:jigongjia/core/utils/privacy_service.dart';

/// Summary panel showing wage total and save button.
class SummaryPanel extends StatelessWidget {
  final bool isRest;
  final bool isEdit;
  final double wage;
  final TextEditingController noteCtrl;
  final VoidCallback onSave;

  const SummaryPanel({
    super.key,
    required this.isRest,
    required this.isEdit,
    required this.wage,
    required this.noteCtrl,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 16),
        TextField(
          controller: noteCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: '备注',
            hintText: '工种、内容、天气...',
            prefixIcon: Icon(Icons.notes),
          ),
        ),
        const SizedBox(height: 20),
        // Wage display
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isRest ? '休息 · 无工资' : '工资合计',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Text(
                PrivacyService.format(wage, hide: PrivacyService().isHidden.value),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onSave,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            isEdit ? '保存修改' : '记录今天',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
