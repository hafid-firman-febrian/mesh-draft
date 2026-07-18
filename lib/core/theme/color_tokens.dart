import 'package:flutter/material.dart';

class MeshColors {
  MeshColors._();

  // Canvas
  static const canvas = Color(0xFF000000);

  // Surface — teal transparan di atas hitam.
  // 0x59 = 35% alpha. Border WAJIB menyertainya (surface terlalu tipis
  // untuk terbaca sebagai kartu tanpa garis tepi).
  static const surface = Color(0x59233D4D); // rgba(35,61,77,0.35)
  static const surfaceBorder = Color(0x802E4E60); // rgba(46,78,96,0.5)
  static const surfaceActive = Color(0xFF2E4E60); // solid — chip aktif, ditekan

  // FAB — solid, menonjol dari canvas
  static const fab = Color(0xFF233D4D);

  // Teks
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9BA8B0);
  static const textMuted = Color(0xFF6E808B);

  // Graph
  static const node = Color(0xFFEAECF0);
  static const edge = Color(0xFF9BA8B0);

  // Danger — SATU-SATUNYA warna dari luar palet, khusus delete
  static const danger = Color(0xFFEF4444);
}

class MeshSpacing {
  MeshSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class MeshRadius {
  MeshRadius._();
  static const sm = 8.0;
  static const md = 14.0;
  static const pill = 999.0;
}
