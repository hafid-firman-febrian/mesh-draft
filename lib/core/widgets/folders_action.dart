import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class FoldersAction extends StatelessWidget {
  const FoldersAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(PhosphorIconsRegular.folder),
      tooltip: 'Folder',
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Segera hadir'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
  }
}
