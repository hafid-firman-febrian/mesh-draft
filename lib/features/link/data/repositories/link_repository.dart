import 'package:drift/drift.dart' show Value;
import 'package:mesh_draft/core/storage/database.dart' as db;
import 'package:mesh_draft/features/link/data/data_sources/link_local_data_source.dart';
import 'package:mesh_draft/features/link/domain/models/note_link_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'link_repository.g.dart';

abstract class LinkRepository {
  Stream<List<NoteLink>> watchAllLinks();
  Stream<List<NoteLink>> watchLinksForNote(String noteId);
  Future<bool> linkExists(String sourceId, String targetId);
  Future<NoteLink> createLink(NoteLink link);
  Future<void> deleteLink(String id);
}

class LinkRepositoryImpl implements LinkRepository {
  LinkRepositoryImpl({required LinkLocalDataSource localDataSource})
      : _local = localDataSource;

  final LinkLocalDataSource _local;

  @override
  Stream<List<NoteLink>> watchAllLinks() {
    return _local.watchAllLinks().map(
          (rows) => rows.map(_toDomain).toList(),
        );
  }

  @override
  Stream<List<NoteLink>> watchLinksForNote(String noteId) {
    return _local.watchLinksForNote(noteId).map(
          (rows) => rows.map(_toDomain).toList(),
        );
  }

  @override
  Future<bool> linkExists(String sourceId, String targetId) =>
      _local.linkExists(sourceId, targetId);

  @override
  Future<NoteLink> createLink(NoteLink link) async {
    final row = await _local.createLink(_toCompanion(link));
    return _toDomain(row);
  }

  @override
  Future<void> deleteLink(String id) => _local.deleteLink(id);

  NoteLink _toDomain(db.NoteLink row) => NoteLink(
        id: row.id,
        sourceId: row.sourceId,
        targetId: row.targetId,
        createdAt: row.createdAt,
      );

  db.NoteLinksCompanion _toCompanion(NoteLink link) => db.NoteLinksCompanion(
        id: Value(link.id),
        sourceId: Value(link.sourceId),
        targetId: Value(link.targetId),
        createdAt: Value(link.createdAt),
      );
}

@riverpod
LinkRepository linkRepository(Ref ref) {
  return LinkRepositoryImpl(
    localDataSource: ref.watch(linkLocalDataSourceProvider),
  );
}
