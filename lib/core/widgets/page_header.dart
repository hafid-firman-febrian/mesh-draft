import 'package:flutter/material.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        MeshSpacing.sm,
        20,
        MeshSpacing.md,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: MeshColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
