import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pracazaliczeniowamobileapp/app/providers.dart';
import 'package:pracazaliczeniowamobileapp/ui/shared/app_notice_banner.dart';

void main() {
  testWidgets(
    'the status banner replaces an earlier message instead of queuing it',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: const AppNoticeBanner(),
                floatingActionButton: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'first',
                      onPressed: () => showAppNotice(ref, 'First action'),
                      child: const Icon(Icons.looks_one),
                    ),
                    FloatingActionButton(
                      heroTag: 'second',
                      onPressed: () => showAppNotice(ref, 'Second action'),
                      child: const Icon(Icons.looks_two),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.looks_one));
      await tester.pump();
      expect(find.text('First action'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.looks_two));
      await tester.pump();
      expect(find.text('First action'), findsNothing);
      expect(find.text('Second action'), findsOneWidget);
    },
  );
}
