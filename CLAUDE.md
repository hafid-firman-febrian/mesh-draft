# CLAUDE.md

## Project Context

Aplikasi catatan mobile Flutter di mana **visualisasi graph adalah produknya**, bukan fitur pelengkap. Target: profesional / knowledge worker. Local-only di MVP.

## Tech Stack

- Framework: Flutter (iOS + Android)
- Language: Dart
- State: Riverpod — `Notifier` / `AsyncNotifier`
- Routing: go_router
- Database: Drift (SQLite), local-only. Supabase → Phase 2
- Model: Freezed
- Graph: `CustomPainter` + `InteractiveViewer`, force simulation manual
- Styling: Material 3, dark mode ikut sistem

## Key Directories

- `docs/` — spesifikasi lengkap. Baca sebelum menulis kode di area yang belum dikenal
- `lib/core/` — theme, constants, database Drift (dipakai lintas feature)
- `lib/features/note/` — CRUD catatan
- `lib/features/link/` — menghubungkan catatan
- `lib/features/graph/` — visualisasi graph
- `lib/router/` — go_router

Struktur tiap feature: `presentation/{controllers,states,pages,widgets}`, `application/services`, `domain/models`, `data/{data_sources,repositories}`

## Commands

- `flutter run` — jalankan di device
- `flutter run --profile` — **wajib untuk profiling graph.** Debug mode 3-10× lebih lambat dan memberi angka palsu
- `dart run build_runner watch --delete-conflicting-outputs` — code generation, biarkan jalan
- `flutter analyze` — linter
- `flutter test` — tests
- `dart format .` — formatter

---

## How I Want You to Work

### Before Coding
- Baca `CLAUDE.md` + dokumen `docs/` yang relevan dulu
- Kalau tidak yakin, tanya — jangan berasumsi
- Untuk kerja kompleks: susun rencana, konfirmasi dulu

### While Coding
- Kode lengkap dan jalan — tanpa placeholder, tanpa TODO
- Sederhana dan terbaca, bukan pintar
- Ikuti pola yang sudah ada di codebase
- Satu layer selesai, verifikasi, baru lanjut — jangan bangun satu feature utuh sekaligus

### After Coding
- `flutter analyze` + `flutter test` setelah **tiap layer**, bukan di akhir
- Ringkas apa yang berubah dan kenapa

---

## Aturan Keras

Aturan di bawah **tidak akan tertangkap `flutter analyze`**. Melanggarnya menghasilkan kode yang terlihat benar tapi salah.

### 1. Pembacaan selalu dari local
Repository tidak pernah remote-first. Tidak ada `try remote → catch → local`. Drift adalah single source of truth. Tetap berlaku setelah Supabase masuk di Phase 2 — yang berubah hanya penulisan (fire-and-forget ke remote setelah local sukses).

### 2. `Notifier` / `AsyncNotifier`, bukan `StateNotifier`
`StateNotifier` ada di `package:flutter_riverpod/legacy.dart`. Jangan pakai. Jangan impor `legacy.dart`.

### 3. Watch, jangan refresh
Controller memakai `Stream` dari Drift (`watchAllNotes()`). Jangan panggil ulang query setelah menulis:
```dart
// ✗ Salah — query ganda, kedipan loading
await service.createNote(...);
await _loadNotes();

// ✓ Benar — Drift memancarkan daftar baru sendiri
await service.createNote(...);
```

### 4. Link dinormalisasi sebelum disimpan
Link dua arah secara semantik. `source_id` **selalu** id yang lebih kecil:
```dart
final (source, target) = a.compareTo(b) < 0 ? (a, b) : (b, a);
```
Tanpa ini, A→B dan B→A tersimpan sebagai dua baris berbeda padahal maknanya sama, dan `UNIQUE(source_id, target_id)` tidak menangkapnya. Aturan ini hidup di `LinkService` — jangan pindahkan ke UI atau repository.

### 5. `PRAGMA foreign_keys = ON`
Ada di `MigrationStrategy.beforeOpen`. Jangan dihapus. SQLite menonaktifkan foreign key secara default — tanpa ini `onDelete: cascade` tidak jalan dan link yatim tertinggal tiap kali catatan dihapus.

### 6. Tanpa JSON
Model Freezed **tanpa** `fromJson`/`toJson`, tanpa `part '*.g.dart'`. Tidak ada API di MVP; Drift generate model sendiri. Ditambahkan di Phase 2.

### 7. Business logic di Services
Bukan di controller, bukan di repository. Controller hanya menyambungkan service ke UI.

---

## Graph Rendering — Terkunci

**`CustomPainter` + `InteractiveViewer`, dengan force simulation manual.**
Jangan pakai `graphview`.

Alasannya bukan performa — keduanya lolos target dengan margin besar. Alasannya: graph MeshDraft harus **hidup**. Bouncing saat load, node bisa di-drag dan tetangganya bereaksi. `graphview` menghitung layout sekali saat init lalu simulasinya mati — tidak bisa bouncing, dan drag akan snap alih-alih mengalir.

Terukur di spike (POCO F4, profile mode, 100 node / 150 edge):
- Pan **sambil simulasi jalan**: build max 5.56ms, raster max 6.25ms — sepertiga dari budget 16ms
- Konvergen: suhu mencapai nol di frame ~420 (~7 detik), bounds beku total setelahnya
- Menyebar organik: 5965×5498 px, tanpa clamp ke viewport

Target tetap: **≤16ms (60fps) saat pan sambil simulasi force berjalan, 100 node**, diukur di HP Android fisik, profile mode.

### Aturan force simulation

Konstanta fisika (`kForceScale`, `kVelocityDamping`, `kTemperatureCutoff`, `kMinDistance`, `kMinSpawnDistance`, `kCoolingFactor`) **tidak boleh diubah tanpa mengukur ulang.** Tiap angka lahir dari bug yang pernah terjadi — mengubahnya tanpa paham menghasilkan getaran tak berujung atau gerakan tersentak.

Kalau harus diubah, wajib:
1. Print `temp`, `maxSpeed`, `maxRawDisp`, dan `bounds` tiap 60 frame
2. Konfirmasi `temp` mencapai 0 dan `bounds` beku (konvergen)
3. Konfirmasi `maxSpeed` **tidak** identik dengan `temp` frame sebelumnya — kalau identik, gerakan digerakkan speed cap, bukan fisika, dan akan terlihat kasar

Aturan lain:
- **Jangan clamp posisi node ke ukuran layar/canvas.** Layout force-directed harus bebas menyebar; `InteractiveViewer` yang mengurus navigasi. Clamp menyebabkan node menumpuk di tepi dan bergetar karena benturan dinding.
- **`InteractiveViewer` wajib `constrained: false`.** Default `true` memaksa konten diperas masuk viewport — layar jadi kosong.
- **Jangan hitung transform awal dari `renderBox.size`.** Frame pertama bisa melaporkan viewport (0,0) dan meracuni transform permanen. Pakai scale tetap.
- **Objek `Random` jangan dibuat ulang tiap frame.** Simpan sebagai field dengan seed tetap — determinisme diperlukan supaya hasil ukur bisa dibandingkan.
- **`CustomPaint` pakai `repaint:` di-hook ke `AnimationController`**, bukan `setState()` — jangan rebuild widget tree tiap frame.
- **`TextPainter` label di-layout sekali**, bukan tiap frame.
- **Ticker boleh berhenti saat konvergen** untuk hemat baterai, tapi harus bisa dibangunkan lagi saat drag atau saat node/link baru ditambah.

---

## Do Not

- **Jangan bangun fitur di luar MVP**, meski terlihat berguna: auth, Supabase, sync, search, settings screen, toggle dark mode manual, AI auto-link, Cornell Notes, tags, rich text, landscape/tablet. Semua sudah dijadwalkan Phase 2+. Menambahkannya sekarang membalikkan keputusan yang diambil sadar.
- **Jangan buat folder** `auth/`, `search/`, `settings/`, atau `dtos/`. Feature MVP: `note`, `link`, `graph`.
- **Jangan pasang paket di luar daftar** (lihat Dependencies di bawah).
- **Jangan ubah konstanta fisika tanpa mengukur ulang.**
- **Jangan salin kode spike bulat-bulat** — `graph_spike/` adalah harness pengukuran, bukan production code. Pindahkan logika fisikanya beserta komentar; buang kode diagnostik dan generator dummy.
- **Jangan tulis komentar yang mengulang kode** — lihat Code Style. Pengecualian: komentar konstanta fisika, itu wajib dipertahankan.
- **Jangan tinggalkan placeholder atau TODO.**
- **Jangan bekerja di luar scope task.**
- Jangan berasumsi — tanya kalau tidak jelas.

---

## Dependencies

Pasang lewat `flutter pub add`, jangan tulis angka versi manual.

**Terpasang:** `flutter_riverpod`, `riverpod_annotation`, `drift`, `drift_flutter`, `go_router`, `freezed_annotation`, `uuid`
**Dev:** `build_runner`, `riverpod_generator`, `drift_dev`, `freezed`, `custom_lint`, `riverpod_lint`

**Jangan pasang tanpa diminta:** `supabase_flutter`, `dio`, `json_serializable`, `flutter_dotenv`, `connectivity_plus`, `graphview` (tidak dipakai — lihat Graph Rendering).

---

## Code Style

- File: snake_case · Class: PascalCase
- Konstanta: `static const` dalam class (`MeshColors.primaryLight`), bukan prefix `k`
- Model tanpa suffix: `Note`, bukan `NoteModel` (file tetap `note_model.dart`)
- Provider dinamai otomatis oleh `@riverpod` — jangan tulis manual
- `NoteLink` hanya didefinisikan di `features/link/domain/models/`. Feature lain mengimpor dari sana
- Nama variabel deskriptif
- Tidak ada kode yang dikomentari-mati

### Komentar

Kode yang baik menjelaskan dirinya sendiri. Nama variabel dan fungsi yang jelas mengalahkan komentar.

**Jangan tulis komentar yang mengulang kode:**
```dart
// ✗ Tidak menambah apa pun
// Ambil semua catatan
Future<List<Note>> getAllNotes() => _local.getAllNotes();

// ✗ Header dekoratif, doc comment basa-basi
// ============================================
// NOTE SERVICE
// ============================================

/// Membuat catatan baru.
Future<Note> createNote(...)
```

**Tulis komentar hanya kalau menjelaskan *kenapa*, bukan *apa*:**
```dart
// ✓ Menjelaskan keputusan yang tidak terbaca dari kode
// SQLite menonaktifkan foreign key secara default — tanpa ini
// onDelete: cascade tidak jalan dan link yatim tertinggal.
await customStatement('PRAGMA foreign_keys = ON');

// ✓ Menjelaskan kenapa bukan cara yang lebih jelas
// Normalisasi urutan: tanpa ini A→B dan B→A tersimpan sebagai
// dua baris berbeda padahal semantiknya sama.
final (source, target) = a.compareTo(b) < 0 ? (a, b) : (b, a);
```

**Pengecualian — konstanta force simulation.** Komentar panjang di `kForceScale`, `kCoolingFactor`, `kMinSpawnDistance`, dll **wajib dipertahankan.** Tiap satu menjelaskan bug yang pernah terjadi kalau angkanya salah. Itu satu-satunya yang mencegah orang mengubahnya sembarangan. Jangan diringkas, jangan dihapus.

---

## Git

### Yang tidak di-commit

Tambahkan ke `.gitignore`:
```
docs/
*.spec.md
*.plan.md
SPIKE_REPORT.md
```

`docs/` dan `CLAUDE.md` adalah konteks untuk agent, bukan artefak proyek. Spec dan plan yang dihasilkan saat bekerja juga tidak di-commit — keduanya jejak proses, bukan hasil.

`CLAUDE.md` sendiri **di-commit** — itu aturan proyek yang harus ikut kalau ada orang lain masuk.

### Pesan commit

Bersih, satu baris, prefix konvensional:
```
feat: add note creation form
fix: normalize link id order to prevent bidirectional duplicates
perf: reduce graph frame time with distance cutoff on repulsion
test: add link service normalization tests
refactor: move validation from controller to service
chore: bump dependencies
```

**Jangan tambahkan:**
- `Co-authored-by:` — tidak ada trailer apa pun
- `🤖 Generated with Claude Code` atau footer sejenis
- Emoji
- Deskripsi panjang di body kecuali memang perlu menjelaskan *kenapa*

Satu commit = satu perubahan logis. Jangan gabungkan feature dengan refactor.

---

## Layar MVP

Graph View, Notes List, Note Detail, Create/Edit Note, Modal Link Note — 4 layar + 1 modal.

---

## Verification Loop

Setelah tiap layer (bukan tiap feature):
1. `flutter analyze` bersih
2. `flutter test` lolos
3. Perubahan sesuai permintaan, tidak lebih

Khusus feature `graph`, tambahan:
4. `flutter run --profile` di HP Android fisik
5. Log menunjukkan `temp` capai 0, `bounds` beku, `maxSpeed` ≠ `temp` frame sebelumnya

Kalau ada yang gagal, perbaiki sebelum menandai selesai.

---

## Prioritas Test

`LinkService` lebih dulu, sebelum yang lain. Di situlah aturan normalisasi berada, dan itu satu-satunya tempat bug duplikat dua arah bisa lolos diam-diam.

Uji dari kedua arah: link A→B, lalu coba B→A — yang kedua harus ditolak.

---

## Success Criteria

Task selesai kalau:
- [ ] Kode jalan sesuai permintaan
- [ ] Test lolos, `flutter analyze` bersih
- [ ] Tidak ada Aturan Keras yang dilanggar
- [ ] Tidak ada fitur Phase 2 yang menyelinap masuk
- [ ] Perubahan minimal dan fokus
- [ ] Saya bisa paham apa yang kamu kerjakan tanpa penjelasan tambahan

---

## Urutan Kerja

1. Setup + core (theme, database)
2. Feature `note` — data → domain → application → presentation
3. Feature `link` — fokus normalisasi
4. Feature `graph` — CustomPainter, bouncing, drag node
5. Polish + test

Berurutan, bukan paralel. `graph` bergantung pada `note` dan `link`.

---

## Notes

- Spike rendering selesai 15 Juli 2026. Kode spike ada di `graph_spike/` (project terpisah) — rujukan untuk fisika, bukan untuk disalin.
- Bouncing di spike masih kasar: spawn `kWorldSize=2400` terlalu rapat (graph settle di 5965×5498), dan repulsi belum punya cutoff jarak. Keduanya perlu diperbaiki saat memindahkan logika ke `GraphLayoutService`.
- Posisi node hasil drag disimpan ke DB (`posX`/`posY` nullable di tabel `Notes`). Null artinya belum pernah diatur user → posisi dihitung simulasi.
