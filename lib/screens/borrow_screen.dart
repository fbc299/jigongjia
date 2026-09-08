import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:jigongjia/models/borrow_record.dart';
import 'package:jigongjia/providers/borrow_provider.dart';
import 'package:jigongjia/core/utils/privacy_service.dart';
import 'package:jigongjia/screens/widgets/record_tile.dart';

class BorrowScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const BorrowScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<BorrowScreen> createState() => _BorrowScreenState();
}

class _BorrowScreenState extends State<BorrowScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BorrowProvider>().loadRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('借支 - ${widget.projectName}'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: PrivacyService().isHidden,
            builder: (_, hidden, __) => IconButton(
              icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
              onPressed: () => PrivacyService().toggle(),
            ),
          ),
        ],
      ),
      body: Consumer<BorrowProvider>(
        builder: (context, borrowProv, _) {
          final total = borrowProv.getTotalBorrowedByProject(widget.projectId);
          final records = borrowProv.getRecordsByProject(widget.projectId);
          records.sort((a, b) => b.date.compareTo(a.date));

          return Column(
            children: [
              _TotalBorrowedHeader(total: total),
              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.money_off, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('暂无借支记录', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return _buildBorrowTile(context, record);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBorrowDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('借支'),
      ),
    );
  }

  Widget _buildBorrowTile(BuildContext context, BorrowRecord record) {
    final dateStr = DateFormat('MM/dd').format(record.date);
    final subtitle = record.note.isNotEmpty
        ? '$dateStr · ${record.note}'
        : dateStr;

    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定删除这条借支记录吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        try {
          context.read<BorrowProvider>().deleteRecord(record.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('借支记录已删除')),
          );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('操作失败: $e')),
            );
          }
        }
      },
      child: GestureDetector(
        onTap: () => _showEditBorrowDialog(context, record),
        child: RecordTile(
          recordType: RecordType.borrow,
          date: record.date,
          amount: record.amount,
          subtitle: subtitle,
        ),
      ),
    );
  }

  void _showAddBorrowDialog(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('新增借支'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: amountController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: '借支金额（元）',
                          prefixIcon: Icon(Icons.money_off),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          final amount = double.tryParse(value ?? '');
                          if (amount == null || amount <= 0) {
                            return '请输入有效金额';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '日期',
                            prefixIcon: Icon(Icons.event),
                          ),
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(selectedDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: '备注',
                          hintText: '可选',
                          prefixIcon: Icon(Icons.notes),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final amount =
                          double.tryParse(amountController.text.trim()) ?? 0;
                      Navigator.of(dialogContext).pop();
                      try {
                        await context.read<BorrowProvider>().addRecord(
                              BorrowRecord(
                                projectId: widget.projectId,
                                amount: amount,
                                date: selectedDate,
                                note: noteController.text.trim(),
                              ),
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('借支成功')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('操作失败: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('确认'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditBorrowDialog(BuildContext context, BorrowRecord record) {
    final amountController = TextEditingController(text: record.amount.toStringAsFixed(record.amount == record.amount.roundToDouble() ? 0 : 2));
    final noteController = TextEditingController(text: record.note);
    final formKey = GlobalKey<FormState>();
    var selectedDate = record.date;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('编辑借支'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setDialogState(() => selectedDate = picked);
                      },
                    ),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '金额', prefixText: '¥'),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      validator: (v) {
                        if (v == null || v.isEmpty) return '请输入金额';
                        if (double.tryParse(v) == null) return '无效金额';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: '备注（可选）'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: dialogContext,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认删除'),
                        content: const Text('确定删除这条借支记录吗？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await context.read<BorrowProvider>().deleteRecord(record.id);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('借支已删除')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
                        }
                      }
                    }
                  },
                  child: Text('删除', style: TextStyle(color: Colors.red[700])),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      final updated = record.copyWith(
                        amount: double.parse(amountController.text),
                        date: selectedDate,
                        note: noteController.text.trim(),
                      );
                      await context.read<BorrowProvider>().updateRecord(updated);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('借支已更新')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('操作失败: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TotalBorrowedHeader extends StatelessWidget {
  final double total;

  const _TotalBorrowedHeader({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.money_off, color: Colors.orange[700], size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '累计借支',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                PrivacyService.format(total, hide: PrivacyService().isHidden.value),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}