import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/models/travel_plan.dart';
import '../../l10n/app_localizations.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.planner)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: plans.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const _PlannerError(),
            data: (items) => items.isEmpty
                ? const _PlannerEmptyState()
                : _PlanList(plans: items),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('planCreate'),
        icon: const Icon(Icons.add),
        label: Text(l10n.newPlan),
      ),
    );
  }
}

class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({super.key});

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _fileName;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateText = DateFormat.yMMMd(
      Localizations.localeOf(context).languageCode,
    ).format(_date);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newPlan)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  l10n.planEditorIntro,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.planName,
                    prefixIcon: const Icon(Icons.edit_calendar_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.planNameRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.planNotesOptional,
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          _dismissKeyboard();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null && mounted) {
                            setState(() => _date = picked);
                          }
                        },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(l10n.dateLabel(dateText)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickAttachment,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_fileName ?? l10n.choosePlanFile),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _createPlan,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward),
                  label: Text(_isSaving ? l10n.creating : l10n.createPlan),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAttachment() async {
    _dismissKeyboard();
    final selected = await openFile();
    if (selected != null && mounted) {
      setState(() => _fileName = selected.name);
    }
  }

  Future<void> _createPlan() async {
    _dismissKeyboard();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final plan = await ref
        .read(planRepositoryProvider)
        .createPlan(
          name: _nameController.text.trim(),
          notes: _notesController.text.trim(),
          date: _date,
          fileName: _fileName,
        );
    if (!mounted) return;
    context.goNamed('planDetails', pathParameters: {'id': plan.id});
  }

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();
}

class _PlanList extends StatelessWidget {
  const _PlanList({required this.plans});

  final List<TravelPlan> plans;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
    itemCount: plans.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final plan = plans[index];
      final date = DateFormat.yMMMd(
        Localizations.localeOf(context).languageCode,
      ).format(plan.date);
      return Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            child: Icon(switch (plan.status) {
              PlanStatus.completed => Icons.check,
              PlanStatus.upcoming => Icons.event_available_outlined,
              PlanStatus.draft => Icons.edit_calendar_outlined,
            }),
          ),
          title: Text(plan.name),
          subtitle: Text(
            plan.notes.isEmpty ? date : '$date\n${plan.notes}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: plan.notes.isNotEmpty,
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.pushNamed('planDetails', pathParameters: {'id': plan.id}),
        ),
      );
    },
  );
}

class _PlannerEmptyState extends StatelessWidget {
  const _PlannerEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.edit_calendar_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context).plannerEmptyTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context).plannerEmptyDescription,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _PlannerError extends StatelessWidget {
  const _PlannerError();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_busy_outlined, size: 48),
        SizedBox(height: 12),
        Text(AppLocalizations.of(context).plansError),
      ],
    ),
  );
}
