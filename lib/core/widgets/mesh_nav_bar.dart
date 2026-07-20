import 'package:flutter/material.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class MeshNavBar extends StatelessWidget {
  const MeshNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onCreatePressed,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: MeshSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavButton(
              icon: PhosphorIconsRegular.note,
              activeIcon: PhosphorIconsFill.note,
              label: 'Notes',
              isActive: currentIndex == 0,
              onTap: () => onDestinationSelected(0),
            ),
            _CreateButton(onTap: onCreatePressed),
            _NavButton(
              icon: PhosphorIconsRegular.graph,
              activeIcon: PhosphorIconsFill.graph,
              label: 'Graph',
              isActive: currentIndex == 1,
              onTap: () => onDestinationSelected(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? MeshColors.surface : Colors.transparent,
          ),
          child: Icon(
            isActive ? activeIcon : icon,
            size: 24,
            color: isActive ? MeshColors.inkPrimary : MeshColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Buat catatan',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: MeshColors.fab,
          ),
          child: const Icon(Icons.add, size: 32, color: MeshColors.inkPrimary),
        ),
      ),
    );
  }
}
