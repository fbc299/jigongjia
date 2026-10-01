import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:jigongjia/models/settlement.dart';
import 'package:jigongjia/providers/settlement_provider.dart';
import 'package:jigongjia/core/utils/privacy_service.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/borrow_provider.dart';
import 'package:jigongjia/screens/widgets/record_tile.dart';

class SettlementScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const SettlementScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettlementProvider>().loadSettlements();
      context.read<WorkProvider>().loadRecords();
      context.read<BorrowProvider>().loadRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('结算 - ${widget.projectName}'),
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
      body: Consumer3<WorkProvider, BorrowProvider, SettlementProvider>(
        builder: (context, workProv, borrowProv, settleProv, _) {
          final totalWage = workProv
              .getRecordsByProject(widget.projectId)
              .fold<double>(0, (sum, r) => sum + r.totalWage);
          final totalBorrowed =
              borrowProv.getTotalBorrowedByProject(widget.projectId);
          final settlements =
              settleProv.getSettlementsByProject(widget.projectId);
          final totalSettled =
              settlements.fold<double>(0, (sum, s) => sum + s.amount);
          final unpaid = totalWage - totalBorrowed - totalSettled;

          settlements.sort((a, b) => b.date.compareTo(a.date));

          return Column(
            children: [
              _SettlementSummary(
                totalWage: totalWage,
                totalBorrowed: totalBorrowed,
                totalSettled: totalSettled,
                unpaid: unpaid,
              ),
              Expanded(
                child: settlements.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('暂无结算记录',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: settlements.length,
                        itemBuilder: (context, index) {
                          final settlement = settlements[index];
                          return _buildSettlementTile(context, settlement);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSettlementDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('结算'),
      ),
    );
  }

  Widget _buildSettlementTile(BuildContext context, Settlement settlement) {
    final dateStr = DateFormat('MM/dd').format(settlement.date);
    final typeLabel = settlement.type == SettlementType.partial
        ? '部分结算'
        : '全额结算';
    final subtitle = settlement.note.isNotEmpty
        ? '$typeLabel · ${settlement.note}'
        : typeLabel;

    return Dismissible(
      key: Key(settlement.id),
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
            content: const Text('确定删除这条结算记录吗？'),
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
          context.read<SettlementProvider>().deleteSettlement(settlement.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('结算记录已删除')),
          );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('操作失败: $e')),
            );
          }
        }
      },
      child: RecordTile(
        recordType: RecordType.settlement,
        date: settlement.date,
        amount: settlement.amount,
        subtitle: subtitle,
      ),
    );
  }

  void _showAddSettlementDialog(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedDate = DateTime.now();
    var selectedType = SettlementType.partial;

    // 全额结算默认带出「未结工资」，避免手算漏扣借支/已结算
    final workProv = context.read<WorkProvider>();
    final borrowProv = context.read<BorrowProvider>();
    final settleProv = context.read<SettlementProvider>();
    final totalWage = workProv
        .getRecordsByProject(widget.projectId)
        .fold<double>(0, (sum, r) => sum + r.totalWage);
    final totalBorrowed =
        borrowProv.getTotalBorrowedByProject(widget.projectId);
    final totalSettled = settleProv
        .getSettlementsByProject(widget.projectId)
        .fold<double>(0, (sum, s) => sum + s.amount);
    final unpaid = (totalWage - totalBorrowed - totalSettled)
        .clamp(0, double.maxFinite)
        .toDouble();
    final unpaidStr = unpaid == unpaid.roundToDouble()
        ? unpaid.toInt().toString()
        : unpaid.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('新增结算'),
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
                          labelText: '结算金额（元）',
                          prefixIcon: Icon(Icons.payments),
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
                      DropdownButtonFormField<SettlementType>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: '结算类型',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: SettlementType.partial,
                            child: Text('部分结算'),
                          ),
                          DropdownMenuItem(
                            value: SettlementType.full,
                            child: Text('全额结算'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedType = value ?? SettlementType.partial;
                            // 切到全额结算时，自动带出未结金额，避免手算漏扣
                            if (value == SettlementType.full &&
                                amountController.text.isEmpty &&
                                unpaid > 0) {
                              amountController.text = unpaidStr;
                            }
                          });
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
                        await context.read<SettlementProvider>().addSettlement(
                              Settlement(
                                projectId: widget.projectId,
                                amount: amount,
                                date: selectedDate,
                                type: selectedType,
                                note: noteController.text.trim(),
                              ),
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('结算成功')),
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
}

class _SettlementSummary extends StatelessWidget {
  final double totalWage;
  final double totalBorrowed;
  final double totalSettled;
  final double unpaid;

  const _SettlementSummary({
    required this.totalWage,
    required this.totalBorrowed,
    required this.totalSettled,
    required this.unpaid,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: '总工资',
            value: totalWage,
            color: Colors.green[700]!,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: '累计借支',
            value: totalBorrowed,
            color: Colors.orange[700]!,
          ),
          const Divider(height: 20),
          const SizedBox(height: 4),
          _SummaryRow(
            label: '已结算',
            value: totalSettled,
            color: Colors.blue[700]!,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: '未结工资',
            value: unpaid,
            color: unpaid > 0 ? Colors.red[700]! : Colors.grey[700]!,
          ),
          const SizedBox(height: 12),
          Text(
            '未结工资 = 总工资 − 累计借支 − 已结算',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          PrivacyService.format(value, hide: PrivacyService().isHidden.value),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}