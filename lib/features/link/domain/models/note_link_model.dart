import 'package:freezed_annotation/freezed_annotation.dart';

part 'note_link_model.freezed.dart';

@freezed
abstract class NoteLink with _$NoteLink {
  const factory NoteLink({
    required String id,
    required String sourceId,
    required String targetId,
    required DateTime createdAt,
  }) = _NoteLink;
}
