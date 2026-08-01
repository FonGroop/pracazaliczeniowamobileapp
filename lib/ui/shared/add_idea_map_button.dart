import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class AddIdeaMapButton extends StatelessWidget {
  const AddIdeaMapButton({
    super.key,
    required this.selectedPosition,
    required this.label,
    required this.disabledTooltip,
    required this.onCreate,
  });

  final LatLng? selectedPosition;
  final String label;
  final String disabledTooltip;
  final ValueChanged<LatLng> onCreate;

  @override
  Widget build(BuildContext context) {
    final position = selectedPosition;
    return FloatingActionButton.extended(
      heroTag: 'new_idea',
      tooltip: position == null ? disabledTooltip : label,
      onPressed: position == null ? null : () => onCreate(position),
      icon: const Icon(Icons.add_location_alt_outlined),
      label: Text(label),
    );
  }
}
