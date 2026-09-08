import 'package:flutter/material.dart';
import 'package:jigongjia/models/work_record.dart';

/// Work type selector with rest toggle.
/// Displays SegmentedButton for work type (point/packageDay/packageQty)
/// and a SwitchListTile for rest toggle.
class WorkTypeSelector extends StatelessWidget {
  final WorkType workType;
  final bool isRest;
  final ValueChanged<WorkType> onWorkTypeChanged;
  final ValueChanged<bool> onRestChanged;

  const WorkTypeSelector({
    super.key,
    required this.workType,
    required this.isRest,
    required this.onWorkTypeChanged,
    required this.onRestChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mode selector
        SegmentedButton<WorkType>(
          segments: const [
            ButtonSegment(
              value: WorkType.point,
              label: Text('点工'),
              icon: Icon(Icons.access_time, size: 18),
            ),
            ButtonSegment(
              value: WorkType.packageDay,
              label: Text('包工·天'),
              icon: Icon(Icons.calendar_view_day, size: 18),
            ),
            ButtonSegment(
              value: WorkType.packageQty,
              label: Text('包工·量'),
              icon: Icon(Icons.straighten, size: 18),
            ),
          ],
          selected: {workType},
          onSelectionChanged: (s) => onWorkTypeChanged(s.first),
        ),
        const SizedBox(height: 16),
        // Rest toggle
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(isRest ? '休息日' : '正常上工'),
          value: isRest,
          onChanged: onRestChanged,
          activeColor: Colors.orange,
        ),
      ],
    );
  }
}
