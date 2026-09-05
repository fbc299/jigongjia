import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../providers/photo_evidence_provider.dart';
import '../providers/project_provider.dart';
import '../models/photo_evidence.dart';
import '../core/utils/watermark_util.dart';

class PhotoEvidenceScreen extends StatefulWidget {
  final String? projectId;

  const PhotoEvidenceScreen({super.key, this.projectId});

  @override
  State<PhotoEvidenceScreen> createState() => _PhotoEvidenceScreenState();
}

class _PhotoEvidenceScreenState extends State<PhotoEvidenceScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _projectId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final photoProvider = context.watch<PhotoEvidenceProvider>();
    final projects = projectProvider.activeProjects;

    if (_projectId == null && projects.isNotEmpty) {
      _projectId = projects.first.id;
    }

    final photos = _projectId != null
        ? photoProvider.getPhotosByProject(_projectId!)
        : <PhotoEvidence>[];

    final project = _projectId != null
        ? projectProvider.getProjectById(_projectId!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照留证'),
        actions: [
          if (projects.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.folder),
              tooltip: '选择项目',
              onSelected: (id) => setState(() => _projectId = id),
              itemBuilder: (_) => projects
                  .map((p) => PopupMenuItem(
                        value: p.id,
                        child: Text(p.name),
                      ))
                  .toList(),
            ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在处理图片...'),
                ],
              ),
            )
          : photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('暂无照片'),
                      const SizedBox(height: 8),
                      const Text('点击下方按钮拍照或从相册选择'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return _buildPhotoCard(photo, project?.name ?? '');
                  },
                ),
      floatingActionButton: _projectId == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'gallery',
                  onPressed: () => _pickImage(ImageSource.gallery),
                  child: const Icon(Icons.photo_library),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'camera',
                  onPressed: () => _pickImage(ImageSource.camera),
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            ),
    );
  }

  Widget _buildPhotoCard(PhotoEvidence photo, String projectName) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _viewPhoto(photo),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(
                File(photo.filePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 48),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.access_time,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(photo.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error),
                    onPressed: () => _deletePhoto(photo),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_projectId == null) return;

    final projectProvider = context.read<ProjectProvider>();
    final project = projectProvider.getProjectById(_projectId!);
    if (project == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isProcessing = true);

      final now = DateTime.now();

      // Add watermark
      final watermarkedPath = await WatermarkUtil.addWatermark(
        image.path,
        project.name,
        now,
      );

      final photoEvidence = PhotoEvidence(
        projectId: _projectId!,
        filePath: watermarkedPath,
        projectName: project.name,
        timestamp: now,
      );

      final provider = context.read<PhotoEvidenceProvider>();
      await provider.addPhoto(photoEvidence);

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('照片已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理失败: $e')),
        );
      }
    }
  }

  void _viewPhoto(PhotoEvidence photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PhotoViewerScreen(
          filePath: photo.filePath,
          projectName: photo.projectName,
          timestamp: photo.timestamp,
        ),
      ),
    );
  }

  Future<void> _deletePhoto(PhotoEvidence photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除照片'),
        content: const Text('确定要删除这张照片吗？'),
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
      final provider = context.read<PhotoEvidenceProvider>();
      await provider.deletePhoto(photo.id);

      // Also delete the file
      final file = File(photo.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}

class _PhotoViewerScreen extends StatelessWidget {
  final String filePath;
  final String projectName;
  final DateTime timestamp;

  const _PhotoViewerScreen({
    required this.filePath,
    required this.projectName,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(projectName),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  SizedBox(height: 8),
                  Text('无法加载图片', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(
          dateFormat.format(timestamp),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
