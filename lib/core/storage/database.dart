import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Notes, NoteLinks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'mesh_draft'));

  // Untuk test: menyuntik executor in-memory (NativeDatabase.memory()) supaya
  // cascade delete & PRAGMA foreign_keys teruji tanpa file DB nyata.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Reset destruktif, bukan migrasi kolom bertahap. MVP local-only: tidak
        // ada data pengguna yang perlu dipertahankan, jadi penambahan posX/posY
        // (schemaVersion 2) cukup dengan membangun ulang skema.
        onUpgrade: (m, from, to) async {
          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
        },
        beforeOpen: (details) async {
          // SQLite menonaktifkan foreign key secara default.
          // Tanpa ini, onDelete: cascade tidak jalan dan link yatim
          // akan tertinggal setiap kali catatan dihapus.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
