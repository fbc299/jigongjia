import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/note_provider.dart';
import '../providers/project_provider.dart';
import '../models/note.dart';

class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    final dateFormat = DateFormat('MM/dd HH:mm');

    List<Note> notes = noteProvider.notes;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      notes = notes.where((n) => n.content.toLowerCase().contains(q)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('记事本'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索笔记...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.5),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: notes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_alt_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(_searchQuery.isNotEmpty ? '未找到匹配的笔记' : '暂无笔记'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                final project = note.projectId != null
                    ? projectProvider.getProjectById(note.projectId!)
                    : null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showNoteDialog(context, note: note),
                    onLongPress: () => _confirmDelete(note),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (project != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.folder_outlined,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    project.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            note.content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dateFormat.format(note.updatedAt),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showNoteDialog(BuildContext context, {Note? note}) async {
    final contentController = TextEditingController(text: note?.content ?? '');
    String? selectedProjectId = note?.projectId;

    final projectProvider = context.read<ProjectProvider>();
    final projects = projectProvider.activeProjects;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(note != null ? '编辑笔记' : '新建笔记'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: contentController,
                      maxLines: 6,
                      minLines: 4,
                      decoration: const InputDecoration(
                        hintText: '输入笔记内容...',
                        alignLabelWithHint: true,
                      ),
                      autofocus: note == null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: selectedProjectId,
                      decoration: const InputDecoration(
                        labelText: '关联项目（可选）',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('无'),
                        ),
                        ...projects.map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            )),
                      ],
                      onChanged: (v) {
                        setDialogState(() => selectedProjectId = v);
                      },
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
      final content = contentController.text.trim();
      if (content.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('笔记内容不能为空')),
        );
        return;
      }

      final noteProvider = context.read<NoteProvider>();

      if (note != null) {
        final updated = note.copyWith(
          content: content,
          projectId: selectedProjectId,
        );
        await noteProvider.updateNote(updated);
      } else {
        final newNote = Note(
          content: content,
          projectId: selectedProjectId,
        );
        await noteProvider.addNote(newNote);
      }
    }
  }

  Future<void> _confirmDelete(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定要删除这条笔记吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<NoteProvider>().deleteNote(note.id);
    }
  }
}
