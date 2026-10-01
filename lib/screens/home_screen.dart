import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:jigongjia/core/utils/privacy_service.dart';

import 'package:jigongjia/providers/project_provider.dart';
import 'package:jigongjia/providers/work_provider.dart';
import 'package:jigongjia/providers/borrow_provider.dart';
import 'package:jigongjia/providers/settlement_provider.dart';
import 'package:jigongjia/providers/expense_provider.dart';
import 'package:jigongjia/providers/note_provider.dart';
import 'package:jigongjia/models/project.dart';
import 'package:jigongjia/models/work_record.dart';
import 'package:jigongjia/screens/project_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool showFab;
  const HomeScreen({super.key, this.showFab = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectProvider>().loadProjects();
      context.read<WorkProvider>().loadRecords();
      context.read<BorrowProvider>().loadRecords();
      context.read<SettlementProvider>().loadSettlements();
      context.read<ExpenseProvider>().loadExpenses();
      context.read<NoteProvider>().loadNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('格格记工'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'archived') {
                _showArchivedProjects(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'archived',
                child: Text('已归档项目'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<ProjectProvider>(
        builder: (context, projectProvider, _) {
          final projects = projectProvider.activeProjects;
          if (projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    '还没有项目',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角 + 创建第一个项目',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              return _ProjectCard(project: projects[index]);
            },
          );
        },
      ),
      floatingActionButton: widget.showFab
          ? FloatingActionButton.extended(
              onPressed: () => _showAddProjectDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('新建项目'),
            )
          : null,
    );
  }

  void _showAddProjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新建项目'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '项目名称',
                hintText: '例如：XX小区3号楼',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入项目名称';
                }
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  Navigator.of(dialogContext).pop();
                  try {
                    await context.read<ProjectProvider>().addProject(
                          Project(name: name),
                        );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('创建失败: $e')),
                      );
                    }
                  }
                }
              },
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
                  final name = nameController.text.trim();
                  Navigator.of(dialogContext).pop();
                  try {
                    await context.read<ProjectProvider>().addProject(
                          Project(name: name),
                        );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('创建失败: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  void _showArchivedProjects(BuildContext context) {
    final archived = context.read<ProjectProvider>().archivedProjects;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    '已归档项目',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: archived.isEmpty
                      ? const Center(child: Text('没有已归档的项目'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: archived.length,
                          itemBuilder: (ctx, index) {
                            final project = archived[index];
                            return ListTile(
                              title: Text(project.name),
                              subtitle: Text(
                                '归档于 ${DateFormat('yyyy-MM-dd').format(project.createdAt)}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.unarchive),
                                onPressed: () {
                                  context
                                      .read<ProjectProvider>()
                                      .updateProject(
                                        project.copyWith(isArchived: false),
                                      );
                                  Navigator.of(ctx).pop();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;

  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Consumer3<WorkProvider, BorrowProvider, SettlementProvider>(
      builder: (context, workProv, borrowProv, settleProv, _) {
        final workRecords = workProv.getRecordsByProject(project.id);
        final totalDays = workRecords.fold<double>(
          0,
          (sum, r) {
            if (r.isRest) return sum;
            switch (r.type) {
              case WorkType.point:
                return sum + r.days;
              case WorkType.packageDay:
                return sum + r.packageDays;
              case WorkType.packageQty:
                return sum + (r.quantity > 0 ? 1.0 : 0.0);
            }
          },
        );
        final totalOvertime = workRecords.fold<double>(
          0,
          (sum, r) => sum + r.overtimeHours,
        );
        final totalWage = workRecords.fold<double>(
          0,
          (sum, r) => sum + r.totalWage,
        );
        final totalBorrowed = borrowProv.getTotalBorrowedByProject(project.id);
        final settlements = settleProv.getSettlementsByProject(project.id);
        final totalSettled = settlements.fold<double>(
          0,
          (sum, s) => sum + s.amount,
        );
        final unpaidWage = totalWage - totalBorrowed - totalSettled;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProjectDetailScreen(projectId: project.id),
                ),
              );
            },
            onLongPress: () => _showProjectMenu(context, project),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.construction,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.calendar_today,
                        label: '累计 $totalDays 天',
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _StatChip(
                        icon: Icons.access_time,
                        label: '加班 ${totalOvertime.toStringAsFixed(1)}h',
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      _StatChip(
                        icon: Icons.attach_money,
                        label: '未发 ${PrivacyService.format(unpaidWage, hide: PrivacyService().isHidden.value)}',
                        color: unpaidWage > 0 ? Colors.green : Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProjectMenu(BuildContext context, Project project) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.archive),
                title: const Text('归档项目'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.read<ProjectProvider>().archiveProject(project.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('项目已归档')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除项目', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDelete(context, project);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除项目「${project.name}」吗？\n该项目下的所有记录也将被删除，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ProjectProvider>().deleteProject(project.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('项目已删除')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
