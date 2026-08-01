import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class AppNoticeBanner extends ConsumerWidget {
  const AppNoticeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(appNoticeProvider);
    return IgnorePointer(
      ignoring: message == null,
      child: SafeArea(
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          offset: message == null ? const Offset(0, -1.3) : Offset.zero,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: message == null ? 0 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Material(
                color: Theme.of(context).colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          message ?? '',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onInverseSurface,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          ref.read(appNoticeProvider.notifier).state = null,
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
