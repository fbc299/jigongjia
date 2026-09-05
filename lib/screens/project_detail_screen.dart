import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:jigongjia/models/project.dart';
import 'package:jigongjia/models/work_record.dart';
import 'package:jigongjia/models/settlement.dart';
import 'package:jigongjia/providers/project_provider.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/borrow_provider.dart';
import 'package:jigongjia/providers/settlement_provider.dart';
import 'package:jigongjia/providers/photo_evidence_provider.dart';
import 'package:jigongjia/screens/work_entry_screen.dart';
import 'package:jigongjia/screens/borrow_screen.dart';
import 'package:jigongjia/screens/settlement_screen.dart';
import 'package:jigongjia/screens/photo_evidence_screen.dart';
import 'package:jigongjia/screens/widgets/stat_card.dart';
import 'package:jigongjia/screens/widgets/record_tile.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkProvider>().loadRecords();
      context.read<BorrowProvider>().loadRecords();
      context.read<SettlementProvider>().loadSettlements();
      context.read<PhotoEvidenceProvider>().loadPhotos();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = context.watch<ProjectProvider>().getProjectById(widget.projectId);
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('项目详情')),
        body: const Center(child: Text('项目不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '记工日记'),
            Tab(text: '借支记录'),
            Tab(text: '结算记录'),
            Tab(text: '拍照留证'),
          ],
        ),
      ),
      body: Column(
        children: [
          _OverviewSection(projectId: widget.projectId),
          _QuickActions(projectId: widget.projectId, project: project),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _WorkRecordsTab(projectId: widget.projectId, project: project),
                _BorrowRecordsTab(projectId: widget.projectId),
                _SettlementRecordsTab(projectId: widget.projectId),
                _PhotoTab(projectId: widget.projectId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final String projectId;

  const _OverviewSection({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Consumer3<WorkProvider, BorrowProvider, SettlementProvider>(
      builder: (context, workProv, borrowProv, settleProv, _) {
        final workRecords = workProv.getRecordsByProject(projectId);
        final totalDays = workRecords.fold<double>(
          0,
          (sum, r) => sum + r.days + r.packageDays,
        );
        final totalWage = workRecords.fold<double>(
          0,
          (sum, r) => sum + r.totalWage,
        );
        final totalBorrowed = borrowProv.getTotalBorrowedByProject(projectId);
        final settlements = settleProv.getSettlementsByProject(projectId);
        final totalSettled = settlements.fold<double>(
          0,
          (sum, s) => sum + s.amount,
        );
        final unpaid = totalWage - totalSettled;

        return Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.calendar_today,
                      label: '累计工天',
                      value: totalDays.toStringAsFixed(1),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      icon: Icons.payments,
                      label: '总工资',
                      value: '¥${totalWage.toStringAsFixed(0)}',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.money_off,
                      label: '累计借支',
                      value: '¥${totalBorrowed.toStringAsFixed(0)}',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      icon: Icons.account_balance_wallet,
                      label: '未结工资',
                      value: '¥${unpaid.toStringAsFixed(0)}',
                      color: unpaid > 0 ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  final String projectId;
  final Project project;

  const _QuickActions({required this.projectId, required this.project});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _ActionChip(
              icon: Icons.edit_note,
              label: '记工',
              color: Colors.blue,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WorkEntryScreen(
                      projectId: projectId,
                      project: project,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionChip(
              icon: Icons.money_off,
              label: '借支',
              color: Colors.orange,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BorrowScreen(
                      projectId: projectId,
                      projectName: project.name,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionChip(
              icon: Icons.camera_alt,
              label: '拍照',
              color: Colors.purple,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PhotoEvidenceScreen(projectId: projectId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkRecordsTab extends StatelessWidget {
  final String projectId;
  final Project project;

  const _WorkRecordsTab({required this.projectId, required this.project});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkProvider>(
      builder: (context, workProv, _) {
        final records = workProv.getRecordsByProject(projectId);
        records.sort((a, b) => b.date.compareTo(a.date));

        if (records.isEmpty) {
          return const _EmptyTab(
            icon: Icons.edit_note,
            message: '暂无日记',
            hint: '点击上方「记工」开始记录',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return _DiaryCard(record: record, project: project, projectId: projectId);
          },
        );
      },
    );
  }
}

class _DiaryCard extends StatelessWidget {
  final WorkRecord record;
  final Project project;
  final String projectId;

  const _DiaryCard({required this.record, required this.project, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekday = ['一', '二', '三', '四', '五', '六', '日'][record.date.weekday - 1];

    String mainText;
    IconData icon;
    Color iconColor;

    if (record.isRest) {
      mainText = '休息日';
      icon = Icons.hotel;
      iconColor = Colors.orange;
    } else if (record.type == WorkType.point) {
      mainText = '${record.days}天';
      if (record.overtimeHours > 0) mainText += ' + 加班${record.overtimeHours.toInt()}h';
      icon = Icons.engineering;
      iconColor = theme.colorScheme.primary;
    } else if (record.type == WorkType.packageDay) {
      mainText = '包工 ${record.packageDays}天';
      icon = Icons.calendar_view_day;
      iconColor = Colors.teal;
    } else {
      mainText = '包工 ${record.quantity}${record.qtyUnit}';
      icon = Icons.straighten;
      iconColor = Colors.indigo;
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkEntryScreen(
              projectId: projectId,
              project: project,
              initialDate: record.date,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            // Date column
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    record.date.day.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                      color: record.isRest ? Colors.orange : theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    '${record.date.month}月\n周$weekday',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey[500], height: 1.2),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: Colors.grey.withOpacity(0.15),
            ),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: iconColor),
                      const SizedBox(width: 6),
                      Text(mainText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  if (record.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 22),
                      child: Text(
                        record.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                ],
              ),
            ),
            // Wage
            Text(
              record.isRest ? '—' : '¥${record.totalWage.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: record.isRest ? Colors.grey[400] : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BorrowRecordsTab extends StatelessWidget {
  final String projectId;

  const _BorrowRecordsTab({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Consumer<BorrowProvider>(
      builder: (context, borrowProv, _) {
        final records = borrowProv.getRecordsByProject(projectId);
        records.sort((a, b) => b.date.compareTo(a.date));

        if (records.isEmpty) {
          return const _EmptyTab(
            icon: Icons.money_off,
            message: '暂无借支记录',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
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
                        style:
                            FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (_) {
                context.read<BorrowProvider>().deleteRecord(record.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('借支记录已删除')),
                );
              },
              child: RecordTile(
                recordType: RecordType.borrow,
                date: record.date,
                amount: record.amount,
                note: record.note,
              ),
            );
          },
        );
      },
    );
  }
}

class _SettlementRecordsTab extends StatelessWidget {
  final String projectId;

  const _SettlementRecordsTab({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettlementProvider>(
      builder: (context, settleProv, _) {
        final settlements = settleProv.getSettlementsByProject(projectId);
        settlements.sort((a, b) => b.date.compareTo(a.date));

        if (settlements.isEmpty) {
          return _EmptyTab(
            icon: Icons.receipt_long,
            message: '暂无结算记录',
            action: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('去结算'),
              onPressed: () {
                final project =
                    context.read<ProjectProvider>().getProjectById(projectId);
                if (project == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettlementScreen(
                      projectId: projectId,
                      projectName: project.name,
                    ),
                  ),
                );
              },
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: settlements.length,
          itemBuilder: (context, index) {
            final settlement = settlements[index];
            final typeLabel = settlement.type == SettlementType.partial
                ? '部分结算'
                : '全额结算';
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
                        style:
                            FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (_) {
                context
                    .read<SettlementProvider>()
                    .deleteSettlement(settlement.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('结算记录已删除')),
                );
              },
              child: RecordTile(
                recordType: RecordType.settlement,
                date: settlement.date,
                amount: settlement.amount,
                subtitle: '$typeLabel · ${settlement.note.isNotEmpty ? settlement.note : "无备注"}',
              ),
            );
          },
        );
      },
    );
  }
}

class _PhotoTab extends StatelessWidget {
  final String projectId;

  const _PhotoTab({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoEvidenceProvider>(
      builder: (context, photoProv, _) {
        final photos = photoProv.getPhotosByProject(projectId);

        if (photos.isEmpty) {
          return _EmptyTab(
            icon: Icons.camera_alt,
            message: '暂无拍照留证',
            action: TextButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('去拍照'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PhotoEvidenceScreen(projectId: projectId),
                  ),
                );
              },
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(photo.filePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;
  final Widget? action;

  const _EmptyTab({
    required this.icon,
    required this.message,
    this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
          if (action != null) ...[
            const SizedBox(height: 8),
            action!,
          ],
        ],
      ),
    );
  }
}