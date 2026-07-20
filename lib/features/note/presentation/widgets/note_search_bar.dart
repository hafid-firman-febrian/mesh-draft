import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_search_controller.dart';

class NoteSearchBar extends ConsumerStatefulWidget {
  const NoteSearchBar({super.key});

  @override
  ConsumerState<NoteSearchBar> createState() => _NoteSearchBarState();
}

class _NoteSearchBarState extends ConsumerState<NoteSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(noteSearchQueryProvider.notifier).setQuery(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: MeshSpacing.md),
      decoration: BoxDecoration(
        color: MeshColors.surface,
        border: Border.all(color: MeshColors.surfaceBorder),
        borderRadius: BorderRadius.circular(MeshRadius.pill),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: MeshColors.inkMuted),
          const SizedBox(width: MeshSpacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: const TextStyle(
                fontSize: 14,
                color: MeshColors.inkPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search notes',
                hintStyle: TextStyle(color: MeshColors.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
