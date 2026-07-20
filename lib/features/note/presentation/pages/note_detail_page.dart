import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_draft/core/exceptions/validation_exception.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/core/utils/date_extensions.dart';
import 'package:mesh_draft/features/link/application/services/link_service.dart';
import 'package:mesh_draft/features/note/application/services/note_service.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_detail_controller.dart';
import 'package:mesh_draft/features/note/presentation/widgets/linked_notes_section.dart';

enum _DetailMenuAction { edit, link, delete }

class NoteDetailPage extends ConsumerStatefulWidget {
  const NoteDetailPage({super.key, this.noteId, this.autoFocusTitle = false});

  final String? noteId;
  final bool autoFocusTitle;

  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();
  Timer? _debounce;
  bool _initialized = false;
  bool _creating = false;
  late String? _currentNoteId = widget.noteId;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_onTitleFocusChange);
    _contentFocus.addListener(_onContentFocusChange);
    _titleController.addListener(_scheduleSave);
    _contentController.addListener(_onContentChanged);

    if (_currentNoteId == null) {
      _initialized = true;
      if (widget.autoFocusTitle) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _titleFocus.requestFocus();
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleFocus
      ..removeListener(_onTitleFocusChange)
      ..dispose();
    _contentFocus
      ..removeListener(_onContentFocusChange)
      ..dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTitleFocusChange() {
    if (!_titleFocus.hasFocus) _saveNow();
  }

  void _onContentFocusChange() {
    if (!_contentFocus.hasFocus) _saveNow();
  }

  void _onContentChanged() {
    setState(() {});
    _scheduleSave();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _saveNow);
  }

  Future<void> _saveNow() async {
    _debounce?.cancel();
    final title = _titleController.text;
    final content = _contentController.text;

    try {
      final noteId = _currentNoteId;
      if (noteId == null) {
        if (_creating || title.trim().isEmpty) return;
        _creating = true;
        final created = await ref
            .read(noteServiceProvider)
            .createNote(title: title, content: content);
        _creating = false;
        if (!mounted) return;
        setState(() => _currentNoteId = created.id);
      } else {
        await ref
            .read(noteDetailControllerProvider(noteId).notifier)
            .updateNote(title: title, content: content);
      }
    } on ValidationException {
      _creating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteId = _currentNoteId;
    final noteAsync = noteId == null
        ? null
        : ref.watch(noteDetailControllerProvider(noteId));
    final linksAsync = noteId == null
        ? null
        : ref.watch(noteLinksProvider(noteId));
    final linkCount = linksAsync?.value?.length ?? 0;

    final note = noteAsync?.value;
    if (!_initialized && note != null) {
      _titleController.text = note.title;
      _contentController.text = note.content;
      _initialized = true;
      if (widget.autoFocusTitle) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _titleFocus.requestFocus();
        });
      }
    }

    final confirmedNotFound =
        noteId != null &&
        note == null &&
        noteAsync != null &&
        noteAsync.hasValue &&
        !noteAsync.isLoading;
    final confirmedError =
        noteId != null &&
        note == null &&
        noteAsync != null &&
        noteAsync.hasError &&
        !noteAsync.hasValue;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (note != null)
            PopupMenuButton<_DetailMenuAction>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) =>
                  _handleMenuAction(context, action, linkCount),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _DetailMenuAction.edit,
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: _DetailMenuAction.link,
                  child: Text('Link'),
                ),
                PopupMenuItem(
                  value: _DetailMenuAction.delete,
                  child: Text('Delete'),
                ),
              ],
            ),
        ],
      ),
      body: confirmedError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(MeshSpacing.lg),
                child: Text(
                  'Gagal memuat catatan: ${noteAsync.error}',
                  style: const TextStyle(color: MeshColors.textSecondary),
                ),
              ),
            )
          : confirmedNotFound
          ? const _NotFound()
          : _buildEditor(context, noteId, note, linkCount),
    );
  }

  Widget _buildEditor(
    BuildContext context,
    String? noteId,
    Note? note,
    int linkCount,
  ) {
    final meta = note != null
        ? '${note.updatedAt.shortDateTime} · ${_contentController.text.length} karakter · $linkCount link'
        : '${_contentController.text.length} karakter · 0 link';

    return Padding(
      padding: const EdgeInsets.all(MeshSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            focusNode: _titleFocus,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: MeshColors.textPrimary,
            ),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Title',
              hintStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: MeshColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: MeshSpacing.xs),
          Text(
            meta,
            style: const TextStyle(fontSize: 12, color: MeshColors.textMuted),
          ),
          const SizedBox(height: MeshSpacing.md),
          Expanded(
            child: TextField(
              controller: _contentController,
              focusNode: _contentFocus,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontSize: 16,
                color: MeshColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: MeshSpacing.lg),
          const Divider(color: MeshColors.canvasBorder),
          const SizedBox(height: MeshSpacing.sm),
          if (noteId != null)
            LinkedNotesSection(noteId: noteId)
          else
            _PendingLinkedNotes(onAddLinkTap: () => _createThenLink(context)),
        ],
      ),
    );
  }

  Future<void> _createThenLink(BuildContext context) async {
    await _saveNow();
    if (_currentNoteId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isi judul dulu sebelum menautkan')),
        );
      }
      return;
    }
    if (context.mounted) context.push('/note/$_currentNoteId/link');
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    _DetailMenuAction action,
    int linkCount,
  ) async {
    switch (action) {
      case _DetailMenuAction.edit:
        _titleFocus.requestFocus();
      case _DetailMenuAction.link:
        context.push('/note/$_currentNoteId/link');
      case _DetailMenuAction.delete:
        await _confirmDelete(context, linkCount);
    }
  }

  Future<void> _confirmDelete(BuildContext context, int linkCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus catatan?'),
        content: Text(
          linkCount > 0
              ? 'Tindakan ini permanen. $linkCount link ikut terhapus.'
              : 'Tindakan ini permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MeshColors.danger,
              // Tanpa ini label memakai colorScheme.onPrimary turunan seed,
              // yang tidak dijamin kontras terhadap danger.
              foregroundColor: MeshColors.textPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _debounce?.cancel();
    await ref
        .read(noteDetailControllerProvider(_currentNoteId!).notifier)
        .deleteNote();
    if (context.mounted) context.pop();
  }
}

class _PendingLinkedNotes extends StatelessWidget {
  const _PendingLinkedNotes({required this.onAddLinkTap});

  final VoidCallback onAddLinkTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LINKED NOTES · 0',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: MeshColors.textSecondary,
          ),
        ),
        const SizedBox(height: MeshSpacing.sm),
        AddLinkButton(onTap: onAddLinkTap),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Catatan tidak ditemukan.',
        style: TextStyle(color: MeshColors.textSecondary),
      ),
    );
  }
}
