import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pracazaliczeniowamobileapp/app/providers.dart';
import 'package:pracazaliczeniowamobileapp/data/models/travel_plan.dart';
import 'package:pracazaliczeniowamobileapp/l10n/app_localizations.dart';
import 'package:pracazaliczeniowamobileapp/ui/screens/planner_screen.dart';

void main() {
  testWidgets('shows a helpful empty state before the first plan is created', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plansProvider.overrideWith(
            (ref) => Stream<List<TravelPlan>>.value(const []),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PlannerScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Plan your next city day'), findsOneWidget);
    expect(find.text('New plan'), findsOneWidget);
  });

  testWidgets('uses Polish labels when Polish is selected', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plansProvider.overrideWith(
            (ref) => Stream<List<TravelPlan>>.value(const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PlannerScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Zaplanuj kolejny dzień w mieście'), findsOneWidget);
    expect(find.text('Nowy plan'), findsOneWidget);
    expect(find.text('Plan your next city day'), findsNothing);
  });
}
