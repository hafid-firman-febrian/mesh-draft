import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mesh_draft/core/exceptions/validation_exception.dart';
import 'package:mesh_draft/features/link/application/services/link_service.dart';
import 'package:mesh_draft/features/note/application/services/note_service.dart';

// ALAT DEV SEMENTARA — untuk menguji graf di skala besar (target performa 100
// node). BUKAN fitur MVP: hanya dipanggil dari tombol yang di-gate kDebugMode
// di GraphPage. Hapus file ini + tombolnya sebelum rilis.

/// Membuat [noteCount] catatan dummy + hingga [linkCount] link acak, lewat
/// service asli (validasi + normalisasi + dedup tetap berjalan). Menumpuk kalau
/// dipanggil berkali-kali — pakai [clearAllNotes] untuk mengosongkan.
Future<void> seedDummyGraph(
  WidgetRef ref, {
  int noteCount = 100,
  int linkCount = 150,
}) async {
  final noteService = ref.read(noteServiceProvider);
  final linkService = ref.read(linkServiceProvider);

  final ids = <String>[];
  for (var i = 0; i < noteCount; i++) {
    final note = await noteService.createNote(title: 'Dummy ${ids.length + 1}');
    ids.add(note.id);
  }

  final rng = Random();
  var created = 0;
  var guard = 0;
  while (created < linkCount && guard < linkCount * 10 && ids.length > 1) {
    guard++;
    final a = ids[rng.nextInt(ids.length)];
    final b = ids[rng.nextInt(ids.length)];
    try {
      await linkService.createLink(a, b);
      created++;
    } on ValidationException {
      // self-link atau duplikat — lewati, coba pasangan lain.
    }
  }
}

/// Menghapus semua catatan (link ikut terhapus via cascade) lewat service asli.
Future<void> clearAllNotes(WidgetRef ref) async {
  final noteService = ref.read(noteServiceProvider);
  final notes = await noteService.watchAllNotes().first;
  for (final note in notes) {
    await noteService.deleteNote(note.id);
  }
}
