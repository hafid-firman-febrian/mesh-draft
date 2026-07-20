import 'package:flutter/material.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.error,
    this.message = 'Gagal memuat catatan',
  });

  final Object error;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MeshSpacing.lg),
        child: Text(
          '$message: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: MeshColors.textSecondary),
        ),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MeshSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: MeshColors.textMuted),
            const SizedBox(height: MeshSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: MeshColors.textSecondary,
              ),
            ),
            if (label != null && action != null) ...[
              const SizedBox(height: MeshSpacing.lg),
              FilledButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add),
                label: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
