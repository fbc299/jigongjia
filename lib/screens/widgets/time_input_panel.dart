import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared numeric input field used by all input panels.
Widget _numField(
  TextEditingController ctrl,
  String label,
  String suffix,
  VoidCallback onChanged,
) {
  return Builder(
    builder: (context) => TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
      ),
      onChanged: (_) => onChanged(),
    ),
  );
}

/// Time input panel for point work (days selector + overtime text input).
class TimeInputPanel extends StatelessWidget {
  final double days;
  final TextEditingController overtimeHoursCtrl;
  final TextEditingController dailyRateCtrl;
  final TextEditingController overtimeRateCtrl;
  final ValueChanged<double> onDaysChanged;
  final VoidCallback onAnyFieldChanged;

  static const _dayOptions = [0.5, 1.0, 1.5, 2.0];

  const TimeInputPanel({
    super.key,
    required this.days,
    required this.overtimeHoursCtrl,
    required this.dailyRateCtrl,
    required this.overtimeRateCtrl,
    required this.onDaysChanged,
    required this.onAnyFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('工天', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Row(
          children: _dayOptions.map((d) {
            final sel = days == d;
            return Expanded(
              child: GestureDetector(
                onTap: () => onDaysChanged(d),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? theme.colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      d == 1.0 ? '全天' : d == 0.5 ? '半天' : '$d天',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _numField(overtimeHoursCtrl, '加班', '小时', onAnyFieldChanged),
        const SizedBox(height: 12),
        _numField(dailyRateCtrl, '日薪', '元/天', onAnyFieldChanged),
        const SizedBox(height: 12),
        _numField(overtimeRateCtrl, '加班薪', '元/时', onAnyFieldChanged),
      ],
    );
  }
}

/// Rate input panel for package-day work.
class PackageDayInputPanel extends StatelessWidget {
  final TextEditingController packageDaysCtrl;
  final TextEditingController packageDayRateCtrl;
  final VoidCallback onAnyFieldChanged;

  const PackageDayInputPanel({
    super.key,
    required this.packageDaysCtrl,
    required this.packageDayRateCtrl,
    required this.onAnyFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _numField(packageDaysCtrl, '天数', '天', onAnyFieldChanged),
        const SizedBox(height: 12),
        _numField(packageDayRateCtrl, '日薪', '元/天', onAnyFieldChanged),
      ],
    );
  }
}

/// Rate input panel for package-qty work.
class PackageQtyInputPanel extends StatelessWidget {
  final TextEditingController quantityCtrl;
  final String qtyUnit;
  final TextEditingController qtyUnitPriceCtrl;
  final ValueChanged<String> onQtyUnitChanged;
  final VoidCallback onAnyFieldChanged;

  static const _qtyUnits = ['平方', '米', '立方', '件'];

  const PackageQtyInputPanel({
    super.key,
    required this.quantityCtrl,
    required this.qtyUnit,
    required this.qtyUnitPriceCtrl,
    required this.onQtyUnitChanged,
    required this.onAnyFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _numField(quantityCtrl, '工程量', qtyUnit, onAnyFieldChanged),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: qtyUnit,
          decoration: const InputDecoration(
            labelText: '单位',
            prefixIcon: Icon(Icons.category),
          ),
          items: _qtyUnits
              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
              .toList(),
          onChanged: (v) => onQtyUnitChanged(v ?? '平方'),
        ),
        const SizedBox(height: 12),
        _numField(qtyUnitPriceCtrl, '单价', '元/$qtyUnit', onAnyFieldChanged),
      ],
    );
  }
}
