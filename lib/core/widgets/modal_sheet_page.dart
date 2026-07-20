import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';

CustomTransitionPage<T> slideUpSheetPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    opaque: false,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: offset, child: child);
    },
  );
}

class ModalSheet extends StatefulWidget {
  const ModalSheet({super.key, required this.child, this.heightFactor = 0.85});

  final Widget child;
  final double heightFactor;

  @override
  State<ModalSheet> createState() => _ModalSheetState();
}

class _ModalSheetState extends State<ModalSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snapBackController;
  double _dragExtent = 0;

  @override
  void initState() {
    super.initState();
    _snapBackController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          setState(() => _dragExtent = _snapBackController.value);
        });
  }

  @override
  void dispose() {
    _snapBackController.dispose();
    super.dispose();
  }

  void _dismiss() => Navigator.of(context).pop();

  void _onHandleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dy).clamp(
        0.0,
        double.infinity,
      );
    });
  }

  void _onHandleDragEnd(DragEndDetails details, double sheetHeight) {
    final shouldDismiss =
        _dragExtent > sheetHeight * 0.25 ||
        details.velocity.pixelsPerSecond.dy > 700;
    if (shouldDismiss) {
      _dismiss();
      return;
    }
    _snapBackController.value = _dragExtent;
    _snapBackController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topGap = screenHeight * (1 - widget.heightFactor);
    final sheetHeight = screenHeight - topGap;

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
            ),
          ),
          Positioned(
            top: topGap + _dragExtent,
            left: 0,
            right: 0,
            height: sheetHeight,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(MeshRadius.md),
              ),
              child: Material(
                color: MeshColors.sheetBackground,
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: _onHandleDragUpdate,
                      onVerticalDragEnd: (details) =>
                          _onHandleDragEnd(details, sheetHeight),
                      child: Container(
                        height: 24,
                        alignment: Alignment.center,
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: MeshColors.canvasBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
