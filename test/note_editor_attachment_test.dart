import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pracazaliczeniowamobileapp/data/models/city_note.dart';
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

  testWidgets('shows the saved attachment name and local storage status', (
    tester,
  ) async {
    final note = CityNote(
      id: 'idea-1',
      title: 'Museum visit',
      body: 'Ticket attached',
      latitude: 52.2297,
      longitude: 21.0122,
      createdAt: DateTime(2026),
      attachmentName: 'ticket.pdf',
      attachmentPath: '/local/ticket.pdf',
      syncStatus: NoteSyncStatus.synced,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: NoteEditorScreen(existingNote: note),
        ),
      ),
    );

    expect(find.text('ticket.pdf'), findsOneWidget);
    expect(find.text('Stored privately on this device'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });
}
