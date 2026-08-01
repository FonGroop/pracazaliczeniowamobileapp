import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/models/tour_place.dart';
import '../../l10n/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placesProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.goToPlanner,
            onPressed: () => context.pushNamed('planner'),
            icon: const Icon(Icons.edit_calendar_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(placesProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WelcomeCard(onPlanTrip: () => context.pushNamed('planner')),
            const SizedBox(height: 20),
            Text(
              l10n.ideasToday,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            places.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => _ErrorPanel(
                error: error.toString(),
                onRetry: () => ref.invalidate(placesProvider),
              ),
              data: (items) => _PlacesGrid(items: items),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.replaceNamed('map'),
        icon: const Icon(Icons.map),
        label: Text(l10n.replaceWithMap),
      ),
    );
  }
}

class _PlacesGrid extends StatelessWidget {
  const _PlacesGrid({required this.items});

  final List<TourPlace> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: constraints.maxWidth < 560 ? 520 : 360,
            mainAxisExtent: 188,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) => _PlaceTile(place: items[index]),
        );
      },
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onPlanTrip});

  final VoidCallback onPlanTrip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 34,
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).welcomeTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(AppLocalizations.of(context).welcomeBody),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: onPlanTrip,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: Text(AppLocalizations.of(context).planADay),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceTile extends ConsumerWidget {
  const _PlaceTile({required this.place});

  final TourPlace place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => context.pushNamed(
          'details',
          pathParameters: {'id': '${place.id}'},
          extra: place,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Text('${place.id}')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      place.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  place.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => context.pushNamed(
                      'details',
                      pathParameters: {'id': '${place.id}'},
                      extra: place,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.openDetails),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: l10n.savePlace,
                    onPressed: () async {
                      await ref.read(placeRepositoryProvider).savePlace(place);
                      if (context.mounted) {
                        showAppNotice(
                          ref,
                          '${place.title}: ${AppLocalizations.of(context).savedFlash}',
                        );
                      }
                    },
                    icon: const Icon(Icons.bookmark_add_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            const Icon(Icons.explore_off_outlined, size: 44),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).guideError,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
