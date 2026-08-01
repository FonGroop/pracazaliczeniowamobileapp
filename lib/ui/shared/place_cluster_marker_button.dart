import 'package:flutter/material.dart';

class PlaceClusterMarkerButton extends StatelessWidget {
  const PlaceClusterMarkerButton({
    super.key,
    required this.count,
    required this.tooltip,
    required this.onPressed,
  });

  final int count;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Badge(label: Text('$count'), child: const Icon(Icons.location_on)),
    );
  }
}
