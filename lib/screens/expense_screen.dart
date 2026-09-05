import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/expense_provider.dart';
import '../models/expense.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  static const _categories = ['吃饭', '交通', '住宿', '其他'];
  static const _categoryIcons = <String, IconData>{
    '吃饭': Icons.restaurant,
    '交通': Icons.directions_car,
    '住宿': Icons.home,
    '其他': Icons.category,
  };
  static const _categoryColors = <String, Color>{
    '吃饭': Colors.orange,
    '交通': Colors.blue,
    '住宿': Colors.purple,
    '其他': Colors.teal,
  };

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final monthlyTotal = expenseProvider.getMonthlyTotal(
      _currentMonth.year,
      _currentMonth.month,
    );
    final categoryTotals = expenseProvider.getCategoryTotals(
      _currentMonth.year,
      _currentMonth.month,
    );
    final monthExpenses = expenseProvider.expenses
        .where((e) =>
            e.date.year == _currentMonth.year &&
            e.date.month == _currentMonth.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final numberFormat = NumberFormat('#,##0.00');
    final monthFormat = DateFormat('yyyy年MM月');

    return Scaffold(
      appBar: AppBar(
        title: const Text('生活开支'),
      ),
      body: Column(
        children: [
          // Month navigator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevMonth,
                ),
                Text(
                  monthFormat.format(_currentMonth),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          // Monthly total
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '本月支出',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¥${numberFormat.format(monthlyTotal)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Category breakdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: _categories.map((cat) {
                final amount = categoryTotals[cat] ?? 0;
                return Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _categoryIcons[cat],
                            color: _categoryColors[cat],
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '¥${numberFormat.format(amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: _categoryColors[cat],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Expense list
          Expanded(
            child: monthExpenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 56,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        const Text('本月暂无开支记录'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: monthExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = monthExpenses[index];
                      return _buildExpenseTile(expense, numberFormat);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense, NumberFormat numberFormat) {
    final dateFormat = DateFormat('MM/dd');
    final catColor = _categoryColors[expense.category] ?? Colors.grey;

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        context.read<ExpenseProvider>().deleteExpense(expense.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: catColor.withOpacity(0.12),
            child: Icon(
              _categoryIcons[expense.category] ?? Icons.category,
              color: catColor,
              size: 20,
            ),
          ),
          title: Text(
            '¥${numberFormat.format(expense.amount)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${expense.category}${expense.note.isNotEmpty ? ' · ${expense.note}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            dateFormat.format(expense.date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }

  Future<void> _showAddExpenseDialog(BuildContext context) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedCategory = '吃饭';
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('添加开支'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '金额',
                        prefixText: '¥ ',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: '类别'),
                      items: _categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedCategory = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, size: 20),
                      title: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: '备注（可选）',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      final amount = double.tryParse(amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效金额')),
        );
        return;
      }

      final expense = Expense(
        amount: amount,
        category: selectedCategory,
        date: selectedDate,
        note: noteController.text.trim(),
      );

      await context.read<ExpenseProvider>().addExpense(expense);
    }
  }
}
