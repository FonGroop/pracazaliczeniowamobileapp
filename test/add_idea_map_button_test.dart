import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pracazaliczeniowamobileapp/ui/shared/add_idea_map_button.dart';

void main() {
  testWidgets('Add idea stays disabled until a map point is selected', (
    tester,
  ) async {
    LatLng? createdAt;

    Widget buildButton(LatLng? selectedPosition) => MaterialApp(
      home: Scaffold(
        floatingActionButton: AddIdeaMapButton(
          selectedPosition: selectedPosition,
          label: 'Add idea',
          disabledTooltip: 'Select a point first',
          onCreate: (position) => createdAt = position,
        ),
      ),
    );

    await tester.pumpWidget(buildButton(null));
    var button = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(button.onPressed, isNull);
    expect(createdAt, isNull);

    const selected = LatLng(50.0614, 19.9366);
    await tester.pumpWidget(buildButton(selected));
    button = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(createdAt, selected);
  });
}
