import 'package:mesh_draft/core/exceptions/validation_exception.dart';
import 'package:mesh_draft/features/link/data/repositories/link_repository.dart';
import 'package:mesh_draft/features/link/domain/models/note_link_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'link_service.g.dart';

class LinkService {
  LinkService(this._repository, this._uuid);

  final LinkRepository _repository;
  final Uuid _uuid;

  Stream<List<NoteLink>> watchAllLinks() => _repository.watchAllLinks();

  Stream<List<NoteLink>> watchLinksForNote(String noteId) =>
      _repository.watchLinksForNote(noteId);

  Future<NoteLink> createLink(String noteA, String noteB) async {
    if (noteA == noteB) {
      throw const ValidationException(
        'Catatan tidak bisa di-link ke dirinya sendiri',
      );
    }

    final (source, target) = noteA.compareTo(noteB) < 0
        ? (noteA, noteB)
        : (noteB, noteA);

    if (await _repository.linkExists(source, target)) {
      throw const ValidationException('Link sudah ada');
    }

    return _repository.createLink(
      NoteLink(
        id: _uuid.v4(),
        sourceId: source,
        targetId: target,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteLink(String id) => _repository.deleteLink(id);
}

@riverpod
LinkService linkService(Ref ref) {
  return LinkService(ref.watch(linkRepositoryProvider), const Uuid());
}

@riverpod
Stream<List<NoteLink>> noteLinks(Ref ref, String noteId) {
  return ref.watch(linkServiceProvider).watchLinksForNote(noteId);
}
