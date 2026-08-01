import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/saved_place_entity.dart';
import '../../l10n/app_localizations.dart';

Future<void> showAddSavedPlaceToPlanSheet({
  required BuildContext context,
  required SavedPlaceEntity place,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (_) => _AddSavedPlaceToPlanSheet(place: place),
);

class _AddSavedPlaceToPlanSheet extends ConsumerWidget {
  const _AddSavedPlaceToPlanSheet({required this.place});

  final SavedPlaceEntity place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final plans = ref.watch(plansProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: plans.when(
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SizedBox(
            height: 180,
            child: Center(child: Text(l10n.plansError)),
          ),
          data: (items) => items.isEmpty
              ? SizedBox(
                  height: 180,
                  child: Center(child: Text(l10n.createPlanBeforeSavedPlace)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.addSavedPlaceToPlan(place.title),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ...items.map(
                      (plan) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.edit_calendar_outlined),
                        title: Text(plan.name),
                        onTap: () async {
                          await ref
                              .read(planRepositoryProvider)
                              .addSavedPlace(plan.id, place);
                          if (context.mounted) {
                            Navigator.pop(context);
                            showAppNotice(ref, l10n.savedPlaceAddedToPlan);
                          }
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
