import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pracazaliczeniowamobileapp/l10n/app_localizations.dart';
import 'package:pracazaliczeniowamobileapp/ui/screens/notes_screen.dart';

void main() {
  testWidgets('offers an attachment picker when creating an idea', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('pl'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: NoteEditorScreen(),
        ),
      ),
    );

    expect(find.text('Wybierz załącznik'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
  });
}
