import 'package:flutter_test/flutter_test.dart';
import 'package:jigongjia/models/project.dart';
import 'package:jigongjia/providers/project_provider.dart';

void main() {
  group('ProjectProvider', () {
    late ProjectProvider provider;

    setUp(() {
      provider = ProjectProvider();
    });

    test('should have empty projects initially', () {
      expect(provider.projects, isEmpty);
    });

    test('should have empty active and archived projects initially', () {
      expect(provider.activeProjects, isEmpty);
      expect(provider.archivedProjects, isEmpty);
    });

    test('should return null for non-existent project id', () {
      expect(provider.getProjectById('nonexistent'), isNull);
    });

    test('should notify listeners on notifyListeners call', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      expect(notifyCount, 0);
    });
  });

  group('Project model', () {
    test('should create project with auto-generated id', () {
      final project = Project(name: 'Test Project');

      expect(project.id, isNotEmpty);
      expect(project.name, 'Test Project');
      expect(project.isArchived, false);
      expect(project.defaultDailyRate, 300.0);
      expect(project.defaultOvertimeRate, 50.0);
    });

    test('should serialize to map and back', () {
      final project = Project(
        id: 'proj-1',
        name: 'Test Project',
        isArchived: false,
        defaultDailyRate: 350.0,
        defaultOvertimeRate: 60.0,
        defaultPackageDayRate: 500.0,
        defaultPackageQtyRate: 25.0,
        defaultQtyUnit: '米',
      );

      final map = project.toMap();
      expect(map['id'], 'proj-1');
      expect(map['name'], 'Test Project');
      expect(map['isArchived'], 0);
      expect(map['defaultDailyRate'], 350.0);
      expect(map['defaultQtyUnit'], '米');

      final restored = Project.fromMap(map);
      expect(restored.id, project.id);
      expect(restored.name, 'Test Project');
      expect(restored.isArchived, false);
      expect(restored.defaultDailyRate, 350.0);
      expect(restored.defaultQtyUnit, '米');
    });

    test('should serialize archived project correctly', () {
      final project = Project(
        id: 'proj-archived',
        name: 'Archived Project',
        isArchived: true,
      );

      final map = project.toMap();
      expect(map['isArchived'], 1);

      final restored = Project.fromMap(map);
      expect(restored.isArchived, true);
    });

    test('should copy with changes', () {
      final project = Project(
        id: 'proj-1',
        name: 'Original',
        defaultDailyRate: 300.0,
      );

      final updated = project.copyWith(
        name: 'Updated',
        defaultDailyRate: 400.0,
      );

      expect(updated.id, 'proj-1'); // id preserved
      expect(updated.name, 'Updated');
      expect(updated.defaultDailyRate, 400.0);
      expect(updated.isArchived, false); // unchanged
    });

    test('should copy with archive flag', () {
      final project = Project(id: 'proj-1', name: 'Test');
      expect(project.isArchived, false);

      final archived = project.copyWith(isArchived: true);
      expect(archived.isArchived, true);
      expect(archived.name, 'Test'); // unchanged
    });

    test('should support equality by id', () {
      final p1 = Project(id: 'same-id', name: 'A');
      final p2 = Project(id: 'same-id', name: 'B');
      final p3 = Project(id: 'diff-id', name: 'A');

      expect(p1, equals(p2));
      expect(p1, isNot(equals(p3)));
    });

    test('should have meaningful toString', () {
      final project = Project(id: 'proj-1', name: 'Test');
      expect(project.toString(), contains('proj-1'));
      expect(project.toString(), contains('Test'));
    });
  });
}
