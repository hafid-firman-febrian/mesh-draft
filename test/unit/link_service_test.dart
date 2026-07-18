import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/core/exceptions/validation_exception.dart';
import 'package:mesh_draft/features/link/application/services/link_service.dart';
import 'package:mesh_draft/features/link/data/repositories/link_repository.dart';
import 'package:mesh_draft/features/link/domain/models/note_link_model.dart';
import 'package:uuid/uuid.dart';

void main() {
  late _FakeLinkRepository repository;
  late LinkService service;

  setUp(() {
    repository = _FakeLinkRepository();
    service = LinkService(repository, const Uuid());
  });

  group('LinkService — normalisasi & duplikat', () {
    test('link A→B lalu B→A ditolak (duplikat dua arah)', () async {
      await service.createLink('a', 'b');
      await expectLater(
        service.createLink('b', 'a'),
        throwsA(isA<ValidationException>()),
      );
      expect(repository.links.length, 1);
    });

    test('self-link ditolak', () async {
      await expectLater(
        service.createLink('a', 'a'),
        throwsA(isA<ValidationException>()),
      );
      expect(repository.links, isEmpty);
    });

    test('normalisasi: source selalu id lebih kecil, argumen (z, a)', () async {
      final link = await service.createLink('z', 'a');
      expect(link.sourceId, 'a');
      expect(link.targetId, 'z');
    });

    test('normalisasi: hasil sama terlepas dari urutan argumen', () async {
      final linkAb = await service.createLink('a', 'b');
      repository.links.clear();
      final linkBa = await service.createLink('b', 'a');
      expect(linkAb.sourceId, linkBa.sourceId);
      expect(linkAb.targetId, linkBa.targetId);
      expect(linkBa.sourceId.compareTo(linkBa.targetId) < 0, isTrue);
    });
  });
}

class _FakeLinkRepository implements LinkRepository {
  final List<NoteLink> links = [];

  @override
  Future<bool> linkExists(String sourceId, String targetId) async {
    return links
        .any((l) => l.sourceId == sourceId && l.targetId == targetId);
  }

  @override
  Future<NoteLink> createLink(NoteLink link) async {
    links.add(link);
    return link;
  }

  @override
  Future<void> deleteLink(String id) async {
    links.removeWhere((l) => l.id == id);
  }

  @override
  Stream<List<NoteLink>> watchAllLinks() => throw UnimplementedError();

  @override
  Stream<List<NoteLink>> watchLinksForNote(String noteId) =>
      throw UnimplementedError();
}
