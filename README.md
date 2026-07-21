# MeshDraft

Aplikasi catatan mobile di mana **visualisasi graph adalah produknya**, bukan fitur pelengkap.

Catatan saling dihubungkan, lalu relasinya dirender sebagai graph force-directed yang hidup — node memantul saat dimuat, bisa di-drag, dan tetangganya ikut bereaksi. Ditujukan untuk knowledge worker yang berpikir lewat koneksi antar-ide, bukan lewat folder.

**Status:** MVP, local-only. Semua data ada di SQLite pada device. Tidak ada akun, tidak ada sync, tidak ada jaringan.

---

## Layar

| Layar | Route | Isi |
|---|---|---|
| Notes List | `/notes` | Grid catatan, pencarian, filter (semua / terhubung / lepas) |
| Graph | `/graph` | Force simulation, pan & zoom, drag node |
| Note Detail | `/note/:id` | Baca & edit, daftar catatan tertaut |
| Create Note | `/create` | Note detail dengan fokus otomatis ke judul |
| Link Modal | `/note/:id/link` | Bottom sheet untuk menautkan ke catatan lain |

Notes dan Graph adalah dua tab dalam `StatefulShellRoute` — state tiap tab bertahan saat berpindah.

---

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

**Langkah `build_runner` tidak opsional.** File `*.g.dart` dan `*.freezed.dart` sengaja tidak di-commit (lihat `.gitignore`), jadi setelah clone project **tidak akan compile** sebelum code generation jalan. Drift, Riverpod, dan Freezed semuanya bergantung padanya.

Selama pengembangan, biarkan mode watch berjalan di terminal terpisah:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

---

## Perintah

```bash
flutter analyze                  # linter
flutter test                     # unit + widget + integration
dart format .                    # formatter
flutter run --profile            # wajib untuk profiling graph
```

Profiling graph **harus** di HP Android fisik dengan `--profile`. Debug mode 3–10× lebih lambat dan memberi angka yang menyesatkan.

---

## Tech Stack

| Bagian | Pilihan |
|---|---|
| Framework | Flutter (iOS + Android) |
| State | Riverpod — `Notifier` / `AsyncNotifier` |
| Routing | go_router |
| Database | Drift (SQLite), local-only |
| Model | Freezed |
| Graph | `CustomPainter` + `InteractiveViewer`, force simulation manual |
| Styling | Material 3, tema gelap |

---

## Struktur

```
lib/
├── core/           theme, storage (Drift), widget & util lintas-feature
├── features/
│   ├── note/       CRUD catatan
│   ├── link/       menghubungkan catatan
│   └── graph/      visualisasi graph
└── router/         go_router
```

Tiap feature memakai lapisan yang sama:

```
data/{data_sources,repositories} → domain/models → application/services → presentation/{controllers,pages,widgets}
```

Business logic tinggal di `application/services`. Controller hanya menyambungkan service ke UI.

---

## Skema Data

Dua tabel, `Notes` dan `NoteLinks`, dengan foreign key cascade dari link ke catatan.

`Notes.posX` / `posY` nullable — `null` berarti user belum pernah menggeser node itu, sehingga posisinya dihitung oleh simulasi. Begitu di-drag, posisinya disimpan dan menjadi pinned.

---

## Keputusan yang Mudah Dilanggar

Empat aturan berikut **tidak akan tertangkap `flutter analyze`**. Melanggarnya menghasilkan kode yang terlihat benar tapi salah.

**1. Link dinormalisasi sebelum disimpan.** Link bersifat dua arah secara semantik, jadi `sourceId` selalu id yang lebih kecil:

```dart
final (source, target) = a.compareTo(b) < 0 ? (a, b) : (b, a);
```

Tanpa ini A→B dan B→A tersimpan sebagai dua baris berbeda padahal maknanya sama, dan `UNIQUE(sourceId, targetId)` tidak menangkapnya. Aturan ini hidup di `LinkService` — bukan di UI, bukan di repository.

**2. `PRAGMA foreign_keys = ON` di `beforeOpen`.** SQLite menonaktifkan foreign key secara default. Tanpa pragma ini `onDelete: cascade` tidak jalan dan link yatim tertinggal setiap kali catatan dihapus.

**3. Pembacaan selalu dari local.** Drift adalah satu-satunya sumber kebenaran. Tidak ada pola `try remote → catch → local`.

**4. Watch, jangan refresh.** Controller memakai `Stream` dari Drift. Jangan panggil ulang query setelah menulis — Drift memancarkan daftar barunya sendiri:

```dart
// ✗ query ganda, kedipan loading
await service.createNote(...);
await _loadNotes();

// ✓
await service.createNote(...);
```

---

## Graph Rendering

`CustomPainter` + `InteractiveViewer` dengan force simulation manual. **Bukan `graphview`.**

Alasannya bukan performa — keduanya lolos target dengan margin besar. Alasannya graph harus *hidup*. `graphview` menghitung layout sekali saat init lalu simulasinya mati: tidak bisa bouncing, dan drag akan snap alih-alih mengalir.

Target performa: **≤16ms (60fps) saat pan sambil simulasi berjalan, 100 node**, diukur di HP Android fisik dalam profile mode.

### Konstanta fisika

Konstanta di `graph_layout_service.dart` (`kForceScale`, `kVelocityDamping`, `kTemperatureCutoff`, `kIdealDistance`, `kRepulsionCutoffFactor`, dan lainnya) **jangan diubah tanpa mengukur ulang.** Tiap angka lahir dari bug nyata; komentar panjang di atasnya menjelaskan bug mana. Komentar itu sengaja dipertahankan.

Kalau memang harus diubah:

1. Print `temp`, `maxSpeed`, `maxRawDisp`, dan `bounds` tiap 60 frame
2. Pastikan `temp` mencapai 0 dan `bounds` beku — tanda konvergen
3. Pastikan `maxSpeed` **tidak** identik dengan `temp` frame sebelumnya. Kalau identik, gerakan digerakkan speed cap alih-alih fisika, dan akan terlihat kasar

### Jebakan rendering

- **Jangan clamp posisi node ke ukuran layar.** Layout force-directed harus bebas menyebar; `InteractiveViewer` yang mengurus navigasi. Clamp bikin node menumpuk di tepi dan bergetar.
- **`InteractiveViewer` wajib `constrained: false`.** Default `true` memeras konten masuk viewport sampai layar tampak kosong.
- **Jangan hitung transform awal dari `renderBox.size`.** Frame pertama bisa melaporkan viewport (0,0) dan meracuni transform secara permanen.
- **`CustomPaint` pakai `repaint:` yang di-hook ke `AnimationController`**, bukan `setState()` per frame.
- **Objek `Random` disimpan sebagai field dengan seed tetap** — determinisme diperlukan agar hasil pengukuran bisa dibandingkan.

---

## Test

```bash
flutter test
```

Cakupan: unit (service & layout), widget (halaman & komponen), dan integration (cascade delete, persistensi posisi node).

`LinkService` adalah prioritas tertinggi — di situlah aturan normalisasi berada, dan itu satu-satunya tempat bug duplikat dua arah bisa lolos diam-diam. Ujilah dari kedua arah: link A→B, lalu coba B→A; yang kedua harus ditolak.

---

## Di Luar Scope MVP

Sudah dijadwalkan untuk fase berikutnya dan **sengaja belum dibangun**: auth, Supabase, sync, settings screen, toggle tema manual, AI auto-link, Cornell Notes, tags, rich text, dan layout landscape/tablet.
