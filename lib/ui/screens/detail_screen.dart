import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/models/tour_place.dart';
import '../../l10n/app_localizations.dart';

class DetailScreen extends ConsumerWidget {
  const DetailScreen({super.key, required this.id, this.place});

  final int id;
  final TourPlace? place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fallback = ref
        .watch(placesProvider)
        .value
        ?.where((item) => item.id == id)
        .firstOrNull;
    final item = place ?? fallback;

    return Scaffold(
      appBar: AppBar(
        title: Text(item?.title ?? l10n.placeFallback(id)),
        leading: IconButton(
          tooltip: l10n.back,
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(
                Icons.place,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                item?.title ?? l10n.placeFallback(id),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(item?.body ?? l10n.placeUnavailable),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: item == null
                    ? null
                    : () async {
                        await ref.read(placeRepositoryProvider).savePlace(item);
                        if (context.mounted) {
                          showAppNotice(ref, l10n.savedPlace);
                        }
                      },
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(l10n.savePlace),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.goNamed('map'),
                icon: const Icon(Icons.map_outlined),
                label: Text(l10n.replaceWithMap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
